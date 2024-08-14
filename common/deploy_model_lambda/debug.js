// Test file for debugging the deploy model lambda in a shell

CONNECTOR_SPEC = {
  "protocol": "aws_sigv4",
  "name": "dev-environment-embedding",
  "description": "Opensearch Connector for cohere.embed-multilingual-v3 via Amazon Bedrock",
  "version": "1",
  "parameters": {
    "model_name": "cohere.embed-multilingual-v3",
    "service_name": "bedrock",
    "region": "us-east-1"
  },
  "actions": [
    {
      "headers": {
        "content-type": "application/json"
      },
      "post_process_function": `def name = 'sentence_embedding';
def dataType = 'FLOAT32';
if (params.embeddings == null || params.embeddings.length == 0) {
return params.message;
}

def embedding = params.embeddings[0];
if (embedding == null || embedding.length == 0) {
return params.message;
}
def shape = [embedding.length];
def json = '{"name":"' + name + '","data_type":"' + dataType + '","shape":' + shape + ',"data":' + embedding + '}';
return json;`,
      "method": "POST",
      "request_body": '{"texts": ${parameters.input}, "input_type": "search_document"}',
      "action_type": "PREDICT",
      "url": "https://bedrock-runtime.${parameters.region}.amazonaws.com/model/${parameters.model_name}/invoke"
    }
  ],
  client_config: {
    max_connection: 200,
    connection_timeout: 2500,
    read_timeout: 30000
  }
}

async function main() {
  const utils = require("./index.js");
  const result = await utils.updateConnector(CONNECTOR_SPEC);
  console.log(JSON.stringify(result));
}

main().then(() => console.log("Done."));
