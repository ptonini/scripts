#!/usr/bin/bash
set -e

function PREPEND_DATE() {
  local LINE
  while read -r LINE
    do echo "$(date "+%y/%m/%d %H:%M:%S") ${1:-INFO} ${LINE}"
  done
}

IFS=$'\n'
LABEL="${INGRESS_BOT_LABEL}=${INGRESS_BOT_LABEL_VALUE}"

echo "starting" | PREPEND_DATE
while true; do

  [[ ${DEBUG} == "true" ]] && echo "fetching services" | PREPEND_DATE DEBUG
  ALL_SERVICES=$(kubectl get services --all-namespaces -l "${LABEL}" --sort-by=.metadata.name -o=jsonpath='{.items}')
  [[ ${DEBUG} == "true" ]] && echo "fetching ingresses" | PREPEND_DATE DEBUG
  ALL_INGRESSES=$(kubectl get ingresses --all-namespaces -l "${LABEL}" --sort-by=.metadata.name -o=jsonpath='{.items}')

  # Build ingress list
  declare -A DESIRED_INGRESSES
  for SERVICE in $(jq -rc '.[]' <<< "${ALL_SERVICES}"); do

    SERVICE_NAME=$(jq -r '.metadata.name' <<< "${SERVICE}")
    NAMESPACE=$(jq -r '.metadata.namespace' <<< "${SERVICE}")
    INGRESS_HOST=$(jq -r --arg A "${INGRESS_HOST_ANNOTATION}" '.metadata.annotations[$A]' <<< "${SERVICE}")
    INGRESS_CLASS=$(jq -r --arg A "${INGRESS_CLASS_ANNOTATION}" '.metadata.annotations[$A]' <<< "${SERVICE}")
    RELEASE_NAME=${INGRESS_HOST//./-}
    [[ ${DEBUG} == "true" ]] && echo "found ingress ${NAMESPACE}/${RELEASE_NAME} in service ${NAMESPACE}/${SERVICE_NAME}" | PREPEND_DATE DEBUG

    # Build ingress object
    INGRESS_VALUES=$(jq -r --arg V "${NAMESPACE}" '. += {"namespace": $V}' <<< "{}")
    INGRESS_VALUES=$(jq -r --arg V "${INGRESS_CLASS}" '. += {"ingressClassName": $V}' <<< "${INGRESS_VALUES}")
    INGRESS_VALUES=$(jq -r --arg V "${INGRESS_HOST}" '. += {"host": $V}' <<< "${INGRESS_VALUES}")

    # Compare configuration with previous iterations and update ingress list
    PREVIOUS_VALUES=${DESIRED_INGRESSES[$RELEASE_NAME]}
    if [[ -n ${PREVIOUS_VALUES} ]]; then

      # Compare namespace
      [[ $(jq -r '.namespace' <<< "${PREVIOUS_VALUES}") != "${NAMESPACE}" ]] && echo "skipping ${NAMESPACE}/${SERVICE_NAME}: mismatched ingress namespace" | PREPEND_DATE ERROR

      # Compare ingress class name
      [[ $(jq -r '.ingressClassName' <<< "${PREVIOUS_VALUES}") != "${INGRESS_CLASS}" ]] && echo "skipping ${NAMESPACE}/${SERVICE_NAME}: mismatched ingress class" | PREPEND_DATE ERROR

    else
      # Add new ingress to desired array
      DESIRED_INGRESSES[$RELEASE_NAME]=${INGRESS_VALUES}
    fi

  done

  # Uninstall serviceless ingresses
  for INGRESS in $(jq -rc '.[]' <<< "${ALL_INGRESSES}"); do
    NAMESPACE=$(jq -r '.metadata.namespace' <<< "${INGRESS}")
    RELEASE_NAME=$(jq -r '.metadata.name' <<< "${INGRESS}")
    if [[ -z ${DESIRED_INGRESSES[$RELEASE_NAME]} ]]; then
      HELM_CMD="helm uninstall -n ${NAMESPACE} ${RELEASE_NAME}"
      HELM_CMD+=$([[ ${DRY_RUN} == "true" ]] && echo " --dry-run" || echo "")
      /bin/bash -c "${HELM_CMD}" | PREPEND_DATE
    fi
  done

  # Create/Update ingresses
  for RELEASE_NAME in "${!DESIRED_INGRESSES[@]}"; do

    INGRESS_VALUES=${DESIRED_INGRESSES[$RELEASE_NAME]}
    NAMESPACE=$(jq -r '.namespace' <<< "${INGRESS_VALUES}")
    HOST=$(jq -r '.host' <<< "${INGRESS_VALUES}")
    INGRESS_CLASS=$(jq -r '.ingressClassName' <<< "${INGRESS_VALUES}")

    UPDATE=${DEFAULT_UPDATE_STATUS}

    # Build ingress paths array from service annotations
    INGRESS_SERVICES=$(jq -r --arg H "${HOST}" --arg N "${NAMESPACE}" --arg A "${INGRESS_HOST_ANNOTATION}" 'map(select((.metadata.namespace == $N) and .metadata.annotations[$A] == $H))' <<< "$ALL_SERVICES")
    INGRESS_PATHS=$(jq -r --arg A "${INGRESS_PATH_ANNOTATION}" 'map({path:.metadata.annotations[$A],service:.metadata.name,port:.spec.ports[0].port})' <<< "${INGRESS_SERVICES}")

    # Compare with current ingress
    CURRENT_INGRESS=$(jq -r --arg N "${RELEASE_NAME}" 'map(select(.metadata.name == $N)) | .[0]' <<< "${ALL_INGRESSES}")
    if [[ ${CURRENT_INGRESS} != "null" ]]; then

      # Compare ingress namespace
      [[ $(jq -r '.namespace' <<< "${INGRESS_VALUES}") != "$(jq -r '.metadata.namespace' <<< "${CURRENT_INGRESS}")" ]] && UPDATE=true

      # Compare ingress class name
      [[ $(jq -r '.ingressClassName' <<< "${INGRESS_VALUES}") != "$(jq -r '.spec.ingressClassName' <<< "${CURRENT_INGRESS}")" ]] && UPDATE=true

      # Compare paths
      PATHS_STRING=$(jq -rc '.[] | [.path,.service,.port] | @csv' <<< "${INGRESS_PATHS}" | sort)
      CURRENT_PATHS_STRING=$(jq -rc '.spec.rules[0].http.paths[] | [.path,.backend.service.name,.backend.service.port.number] | @csv' <<< "${CURRENT_INGRESS}" | sort)
      [[ ${PATHS_STRING} != "${CURRENT_PATHS_STRING}" ]] && UPDATE=true

      [[ ${DEBUG} == "true" ]] && ${UPDATE} && echo "updating ingress ${NAMESPACE}/${RELEASE_NAME}" | PREPEND_DATE DEBUG

    else
      UPDATE=true
      INGRESS_LOADBALANCER=$(kubectl get --all-namespaces services -l "app.kubernetes.io/instance=${INGRESS_CLASS}" -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].ip}')
      [[ -n ${OFFICE_WEBHOOK} ]] && curl "${OFFICE_WEBHOOK}" -H "Expect:" -H 'Content-Type: application/json; charset=utf-8' --data-binary @- << EOF
      {
				 "type":"message",
				 "attachments":[
						{
							 "contentType":"application/vnd.microsoft.card.adaptive",
							 "contentUrl":null,
							 "content": {
									"type": "AdaptiveCard",
									"$schema": "https://adaptivecards.io/schemas/adaptive-card.json",
									"version": "1.6",
									"body": [
										{
											"type": "TextBlock",
											"text": "Ingresso cadastrado",
											"wrap": true,
											"weight": "Bolder"
										},
										{
											"type": "FactSet",
											"facts": [
												{"title": "Cluster", "value": "${CLUSTER_NAME}"},
												{"title": "Hostname", "value": "${HOST}"},
												{"title": "LoadBalancer", "value": "${INGRESS_LOADBALANCER}"}
											]
										}
									]
							 }
						}
				 ]
			}
EOF
      [[ ${DEBUG} == "true" ]] && echo "creating ingress ${NAMESPACE}/${RELEASE_NAME}" | PREPEND_DATE DEBUG
    fi

    # Apply ingress
    if ${UPDATE}; then
      for A in ${EXTRA_ANNOTATIONS}; do
        INGRESS_VALUES=$(jq -r --argjson A "${A}" '.annotations += $A' <<< "${INGRESS_VALUES}")
      done
      INGRESS_VALUES=$(jq -r --argjson V "{\"${INGRESS_BOT_LABEL}\": \"${INGRESS_BOT_LABEL_VALUE}\"}" '.labels += $V' <<< "${INGRESS_VALUES}")
      INGRESS_VALUES=$(jq -r --argjson P "${INGRESS_PATHS}" '. + {"paths": $P}' <<< "${INGRESS_VALUES}")
      [[ ${DEBUG} == "true" ]] && echo "${INGRESS_VALUES}" | PREPEND_DATE DEBUG
      VALUES_FILE=$(mktemp)
      echo "${INGRESS_VALUES}" > "${VALUES_FILE}"
      HELM_CMD="helm upgrade --install -f ${VALUES_FILE} -n ${NAMESPACE} --repo ${CHARTS_REPOSITORY} ${RELEASE_NAME} ${INGRESS_CHART}"
      HELM_CMD+=$(test -n "${INGRESS_CHART_VERSION}" && echo " --version ${INGRESS_CHART_VERSION}" || echo "")
      HELM_CMD+=$([[ ${DRY_RUN} == "true" ]] && echo " --dry-run" || echo "")
      /bin/bash -c "${HELM_CMD}" | PREPEND_DATE
      rm "${VALUES_FILE}"
    else
      [[ ${DEBUG} == "true" ]] && echo "ingress ${NAMESPACE}/${RELEASE_NAME} is up to date" | PREPEND_DATE DEBUG
    fi

  done

  unset DESIRED_INGRESSES
  unset ALL_INGRESSES
  unset ALL_SERVICES
  sleep "${INTERVAL:-1m}"

done