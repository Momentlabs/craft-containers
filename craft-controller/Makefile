repo := craft-controller

# AWS configuration
aws_repo := 033441544097.dkr.ecr.us-east-1.amazonaws.com
profile := momentlabs
region := us-east-1

help:
	@echo local \# builds the dockerfile localy to $(rep)
	@echo test-local \# smoke test on the installed binary.
	@echo deploy-to-repo \# builds and pushes the file the AWS repo.
	@echo latest is: $(craft-config-latest)


# get-latest: craft-config-latest := $(shell curl  -s https://api.github.com/repos/Momentlabs/craft-config/releases | jq -r '.[0].assets[].browser_download_url' | grep linux)
# get-latest:
# @echo latest: $(craft-config-latest)

craft-config-latest := $(shell curl  -s https://api.github.com/repos/Momentlabs/craft-config/releases | jq -r '.[0].assets[].browser_download_url' | grep linux)

local:
	@echo building local image: $(repo) with $(craft-config-latest)
	docker build --build-arg craft_config_url=$(craft-config-latest) -t $(repo) .

test-local: local
	docker run -it --rm --entrypoint craft-config $(repo) version

# Man, this shit has to stop. Either move to rake or look for an alternative.
deploy-to-repo: login := $(shell aws --profile $(profile) --region $(region) --output text ecr get-login )
deploy-to-repo: token := $(shell echo $(login) | awk '{print $$6}')

# @echo Bulding and pushing repository repository:$(repo)
deploy-to-repo: test-local
	@echo logging into AWS before push.
	@docker login -u AWS -p $(token) $(aws_repo)
	docker tag $(repo):latest $(aws_repo)/$(repo):latest
	docker push $(aws_repo)/$(repo):latest
