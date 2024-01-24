# Instala ptonini/toolbox no contexto corrente
helm install --namespace default toolbox workload --repo https://ptonini.github.io/helm-charts --set image=ghcr.io/ptonini/toolbox:latest

# Cria os certificados para o proxy do Postman (Flatpack)
openssl req -subj '/C=US/CN=Postman Proxy' -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -keyout ~/.var/app/com.getpostman.Postman/config/postman-proxy-ca.key -out ~/.var/app/com.getpostman.Postman/config/postman-proxy-ca.crt

# Busca a assinatura do certificado para endpoint oidc do serviço eks
openssl s_client -servername "oidc.eks.us-east-1.amazonaws.com" -showcerts -connect "oidc.eks.us-east-1.amazonaws.com:443" 2>&- | tac | sed -n '/-----END CERTIFICATE-----/,/-----BEGIN CERTIFICATE-----/p; /-----BEGIN CERTIFICATE-----/q' | tac | openssl x509 -fingerprint -noout | sed 's/://g' | awk -F= '{print tolower($2)}'

# Lista resource requests
kubectl -n prd get deploy -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.replicas, .spec.template.spec.containers[0].resources}{"\n"}{end}'

# Aplica bucket policy
aws s3api put-bucket-policy --bucket "${B}" --policy "${POLICY}"

# Sincroniza s3 bucket com pasta local
aws s3 sync s3://nodis-resources/ ./nodis-resources

# Copia pasta local para Azure Storage Container
az storage azcopy blob upload -c nodis-archive --account-name systems739655753 -s /data/nodis-resources --recursive

# Converter json para yaml
for R in ./*; do yq -oy "$R" > "$(basename "$R" .json).yaml"; done

# Remove git tags
for T in $(git tag); do git tag -d "${T}" && git push --delete origin "${T}"; done