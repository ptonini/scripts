package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"sync"
	"time"

	"github.com/Songmu/prompter"
	"github.com/hashicorp/vault-client-go"
	"github.com/hashicorp/vault-client-go/schema"
	"github.com/manifoldco/promptui"
)

const (
	maxConcurrentJobs = 100
	authPath          = `auth/github/login`
)

type Token struct {
	Accessor  string `json:"accessor"`
	Path      string `json:"path"`
	IssueTime string `json:"issue_time"`
	Meta      struct {
		Org      string `json:"org"`
		Username string `json:"username"`
	} `json:"meta"`
}

func getToken(ctx context.Context, client *vault.Client, accessorId string) Token {
	var token Token
	response, err := client.Auth.TokenLookUpAccessor(ctx, schema.TokenLookUpAccessorRequest{Accessor: accessorId})
	if err == nil && response != nil {
		jsonData, _ := json.Marshal(response.Data)
		_ = json.Unmarshal(jsonData, &token)
	}
	return token
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

	// get accessors
	response, err := client.Auth.TokenListAccessors(ctx)
	if err != nil {
		log.Fatal(err)
	}

	accessors := response.Data["keys"].([]interface{})
	fmt.Printf("found %d tokens\n", len(accessors))

	var wg sync.WaitGroup
	var matched []Token
	waitChan := make(chan struct{}, maxConcurrentJobs)
	wg.Add(len(accessors))

	for i := 0; i < len(accessors); i++ {
		waitChan <- struct{}{}
		go func(count int) {
			fmt.Printf("\rread %d tokens", count)
			token := getToken(ctx, client, accessors[count].(string))
			if token.Path == authPath {
				matched = append(matched, token)
			}
			<-waitChan
			defer wg.Done()
		}(i)
	}
	wg.Wait()

	userTokens := map[string][]Token{}
	for _, t := range matched {
		userTokens[t.Meta.Username] = append(userTokens[t.Meta.Username], t)
	}

	var menuItems []string
	for k, _ := range userTokens {
		menuItems = append(menuItems, k)
	}
	prompt := promptui.Select{
		Label: "Select user",
		Items: menuItems,
		Size:  20,
	}
	_, username, _ := prompt.Run()

	if prompter.YesNo(fmt.Sprintf("User %s has %d active tokens. Delete?\n", username, len(userTokens[username])), false) {
		for _, t := range userTokens[username] {
			fmt.Printf("deleting %s\n", t.Accessor)
			_, e := client.Auth.TokenRevokeAccessor(ctx, schema.TokenRevokeAccessorRequest{Accessor: t.Accessor})
			if e != nil {
				fmt.Printf("%v\n", e)
			}
		}
	}
}
