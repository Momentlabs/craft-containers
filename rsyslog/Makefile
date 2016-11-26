repo := craft-rsyslog

# AWS Config
aws_repo := 033441544097.dkr.ecr.us-east-1.amazonaws.com
profile := momentlabs
region := us-east-1

# Get an auth-token to let docker use the AWS Repository (ecr).
login := $(shell aws --profile $(profile) --region $(region) --output text ecr get-login)
token := $(shell echo $(login)| awk '{print $$6}')

help:
	@echo local \# builds the dockerfile localy to $(repo)
	@echo deploy-to-repo \# builds and pushes the file to the AWS repo.

local:
	@echo building local image: $(repo)
	docker build --no-cache -t $(repo) .

test: local
	@echo testing $(repo)
	docker run -it --rm --name $(repo)-test $(repo)


deploy-to-repo: local
	@echo Bulding and pushing repository repository: $(repo)
	docker login -u AWS -p $(token) $(aws_repo)
	docker tag $(repo):latest $(aws_repo)/$(repo):latest
	docker push $(aws_repo)/$(repo):latest