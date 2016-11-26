
repo := craft-server

# AWS Config
aws_repo := 033441544097.dkr.ecr.us-east-1.amazonaws.com
profile := momentlabs
region := us-east-1

# GEt an auth-token to enable docker to use the AWS Repository.
login := $(shell aws --profile $(profile) --region $(region) --output text ecr get-login)
token := $(shell echo $(login)| awk '{print $$6}')

help:
	@echo local-force \# build the image from the dockerfile from scratch, no-cache, locally to $(repo)
	@echo local \# build the image from the dockerfile localy to $(repo)
	@echo deploy-to-repo \# builds and pushes the file the AWS repo.

list-account:
	@echo Using account $(shell aws --profile $(profile) --region $(region) --output text sts get-caller-identity)
	@echo with $(shell aws --profile $(profile) --region $(region) --output text iam list-account-aliases)

local-force: 
	@echo building local image: $(repo) NO-CACHE
	docker build --no-cache -t $(repo) .

local: 
	@echo building local image: $(repo)
	docker build -t $(repo) .

deploy-to-repo: local
	@echo Bulding and pusing repository repository: $(repo)
	docker login -u AWS -p $(token) $(aws_repo)
	docker tag $(repo):latest $(aws_repo)/$(repo):latest
	docker push $(aws_repo)/$(repo):latest