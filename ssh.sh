export DATASET_NAME=news_classification_dataset
export PROJECT=$(gcloud config get-value project)
export API_KEY=YOUR_API_KEY


cat << EOF > request.json
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"A Smoky Lobster Salad With a Tapa Twist. This spin on the Spanish pulpo a la gallega skips the octopus, but keeps the sea salt, olive oil, pimentón and boiled potatoes."
  }
}
EOF

  curl "https://language.googleapis.com/v1/documents:classifyText?key=$API_KEY" \
  -s -X POST -H "Content-Type: application/json" --data-binary @request.json > result.json

# uncomment to show data
# gsutil cat gs://spls/gsp063/bbc_dataset/entertainment/001.txt

# create dataset bigquery
bq --location=US mk -d \
$PROJECT:$DATASET_NAME


# create table
bq mk \
-t \
$DATASET_NAME.article_data \
article_text:STRING,category:STRING,confidence:FLOAT