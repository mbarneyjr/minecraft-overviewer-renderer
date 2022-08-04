MAKEFLAGS=--warn-undefined-variables

AWS_REGION ?= us-east-1

node_modules: package-lock.json
	npm ci
	touch node_modules

.PHONY: dependencies create-change-set deploy-change-set
dependencies: node_modules
	pip install -r requirements.txt

lint:
	cfn-lint

create-change-set: node_modules
	@echo "Deploying ${STACK_NAME} with changeset ${CHANGE_SET_NAME}"
	aws cloudformation create-change-set \
		--stack-name ${STACK_NAME} \
		--template-body file://template.yml \
		--parameters \
			ParameterKey=RepositoryName,ParameterValue='"${REPOSITORY_NAME}"' \
			ParameterKey=OrganizationId,ParameterValue='"${ORGANIZATION_ID}"' \
		--tags \
			Key=ApplicationName,Value=${STACK_NAME} \
			Key=EnvironmentName,Value=prod \
			Key=workload,Value=${STACK_NAME} \
		--capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM CAPABILITY_IAM \
		--change-set-name ${CHANGE_SET_NAME} \
		--description "${CHANGE_SET_DESCRIPTION}" \
		--include-nested-stacks \
		--change-set-type $$(aws cloudformation describe-stacks --stack-name ${STACK_NAME} &> /dev/null && echo "UPDATE" || echo "CREATE")
	@echo "Waiting for change set to be created..."
	@CHANGE_SET_STATUS=None; \
	while [[ "$$CHANGE_SET_STATUS" != "CREATE_COMPLETE" && "$$CHANGE_SET_STATUS" != "FAILED" ]]; do \
		CHANGE_SET_STATUS=$$(aws cloudformation describe-change-set --stack-name ${STACK_NAME} --change-set-name ${CHANGE_SET_NAME} --output text --query 'Status'); \
	done; \
	aws cloudformation describe-change-set --stack-name ${STACK_NAME} --change-set-name ${CHANGE_SET_NAME} > artifacts/${STACK_NAME}-${CHANGE_SET_NAME}.json; \
	if [[ "$$CHANGE_SET_STATUS" == "FAILED" ]]; then \
		CHANGE_SET_STATUS_REASON=$$(aws cloudformation describe-change-set --stack-name ${STACK_NAME} --change-set-name ${CHANGE_SET_NAME} --output text --query 'StatusReason'); \
		if [[ "$$CHANGE_SET_STATUS_REASON" == "The submitted information didn't contain changes. Submit different information to create a change set." ]]; then \
			echo "ChangeSet contains no changes."; \
		else \
			echo "Change set failed to create."; \
			echo "$$CHANGE_SET_STATUS_REASON"; \
			exit 1; \
		fi; \
	fi;
	@echo "Change set ${STACK_NAME} - ${CHANGE_SET_NAME} created."
	npx cfn-changeset-viewer --stack-name ${STACK_NAME} --change-set-name ${CHANGE_SET_NAME}

deploy-change-set: node_modules
	CHANGE_SET_STATUS=$$(aws cloudformation describe-change-set --stack-name ${STACK_NAME} --change-set-name ${CHANGE_SET_NAME} --output text --query 'Status'); \
	if [[ "$$CHANGE_SET_STATUS" == "FAILED" ]]; then \
		CHANGE_SET_STATUS_REASON=$$(aws cloudformation describe-change-set --stack-name ${STACK_NAME} --change-set-name ${CHANGE_SET_NAME} --output text --query 'StatusReason'); \
		echo "$$CHANGE_SET_STATUS_REASON"; \
		if [[ "$$CHANGE_SET_STATUS_REASON" == "The submitted information didn't contain changes. Submit different information to create a change set." ]]; then \
			echo "ChangeSet contains no changes."; \
		else \
			echo "Change set failed to create."; \
			exit 1; \
		fi; \
	else \
		aws cloudformation execute-change-set \
			--stack-name ${STACK_NAME} \
			--change-set-name ${CHANGE_SET_NAME}; \
	fi;
	npx cfn-event-tailer ${STACK_NAME}
