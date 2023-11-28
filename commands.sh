
# Instala ptonini/toolbox no contexto corrente
helm install --namespace default toolbox ptonini/workload --set image=ghcr.io/ptonini/toolbox:latest --set-json service='{"enabled": false}'

# Cria os certificados para o proxy do Postman (Flatpack)
openssl req -subj '/C=US/CN=Postman Proxy' -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -keyout ~/.var/app/com.getpostman.Postman/config/postman-proxy-ca.key -out ~/.var/app/com.getpostman.Postman/config/postman-proxy-ca.crt

# Busca a assinatura do certificado para endpoint oidc do serviço eks
openssl s_client -servername "oidc.eks.us-east-1.amazonaws.com" -showcerts -connect "oidc.eks.us-east-1.amazonaws.com:443" 2>&- | tac | sed -n '/-----END CERTIFICATE-----/,/-----BEGIN CERTIFICATE-----/p; /-----BEGIN CERTIFICATE-----/q' | tac | openssl x509 -fingerprint -noout | sed 's/://g' | awk -F= '{print tolower($2)}'

# Listar resource requests
kubectl -n prd get deploy -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].resources}{"\n"}{end}'