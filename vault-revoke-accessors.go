package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/hashicorp/vault-client-go"
	"github.com/hashicorp/vault-client-go/schema"
	"log"
	"os"
	"time"
)

const (
	maxConcurrentJobs = 100
	githubPath        = `auth/github/login`
)

type Token struct {
	Path string `json:"path"`
	Meta struct {
		Org      string `json:"org"`
		Username string `json:"username"`
	} `json:"meta"`
}

func getToken(ctx context.Context, client *vault.Client, accessorId string, failedChan chan string, matchedChan chan Token) {
	var token Token
	response, _ := client.Auth.TokenLookUpAccessor(ctx, schema.TokenLookUpAccessorRequest{Accessor: accessorId})
	if response != nil {
		jsonData, _ := json.Marshal(response.Data)
		_ = json.Unmarshal(jsonData, &token)
		failedChan <- ""
	} else {
		failedChan <- accessorId
	}
}

func main() {

	ctx := context.Background()

	// prepare a client with the given base address
	client, err := vault.New(
		vault.WithAddress(os.Getenv("VAULT_ADDR")),
		vault.WithRequestTimeout(30*time.Second),
	)
	if err != nil {
		log.Fatal(err)
	}

	// authenticate with a root token (insecure)
	if err = client.SetToken(os.Getenv("VAULT_TOKEN")); err != nil {
		log.Fatal(err)
	}

	// get accessorIds
	response, err := client.Auth.TokenListAccessors(ctx)
	if err != nil {
		log.Fatal(err)
	}
	untypedAccessorIds := response.Data["keys"].([]interface{})
	accessorIds := make([]string, len(untypedAccessorIds))
	for i, v := range untypedAccessorIds {
		accessorIds[i] = v.(string)
	}

	fmt.Printf("found %d tokens\n", len(accessorIds))

	waitChan := make(chan struct{}, maxConcurrentJobs)
	failedChan := make(chan string)
	matchedChan := make(chan Token)
	finishedChan := make(chan bool)

	for i := 0; i < len(accessorIds); i++ {
		fmt.Printf("\rreading token %d", i)
		waitChan <- struct{}{}
		go func(count int) {
			getToken(ctx, client, accessorIds[count], failedChan, matchedChan)
			<-waitChan
			finishedChan <- true
		}(i)
	}

	failed := make([]string, 0)
	matched := make(map[Token]struct{}, 0)
	for i := 0; i < len(accessorIds); {
		select {
		case accessorId := <-failedChan:
			failed = append(failed, accessorId)
		//case token := <-matchedChan:
		//	matched[token] = struct{}{}
		case <-finishedChan:
			i++
		}
	}

	fmt.Printf("\nmatched tokens: %d", len(matched))
	fmt.Printf("\nfailed accessorIds: %d", len(failed))
}
