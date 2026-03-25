LAMBDA_DIR := modules/lambda
ZIP_FILE   := function.zip

.PHONY: build zip clean

build:
	cd $(LAMBDA_DIR) && go mod tidy && GOOS=linux GOARCH=arm64 go build -o bootstrap .

zip: build
	cd $(LAMBDA_DIR) && zip -j ../../$(ZIP_FILE) bootstrap

clean:
	rm -f $(LAMBDA_DIR)/bootstrap $(ZIP_FILE)
