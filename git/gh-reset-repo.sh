gh repo delete linxsa/helm-charts --yes
rm -rf .git
git init
gh repo create linxsa/helm-charts --source . --internal
gh variable set repository_type -b chartmuseum
gh variable set repository_url -b https://chartmuseum.redhill-9136bbe6.eastus2.azurecontainerapps.io
gh secret set repository_username -b cloudops
gh secret set repository_password -b 1234@asdf
