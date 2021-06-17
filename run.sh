export PROJECT=$(gcloud config get-value project)
#export BUCKET_NAME=$PROJECT-bucket
export API_KEY=$1
export DATASET_NAME=news_classification_dataset


cat << EOF > request.json
{
  "document":{
    "type":"PLAIN_TEXT",
    "content":"A Smoky Lobster Salad With a Tapa Twist. This spin on the Spanish pulpo a la gallega skips the octopus, but keeps the sea salt, olive oil, pimentón and boiled potatoes."
  }
}
EOF

  curl "https://language.googleapis.com/v1/documents:classifyText?key=AIzaSyB8XNFrOVnSOdX6qvoywx56SzYo97MltRo" \
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

# classifying news data
# create a service account
gcloud iam service-accounts create my-account --display-name my-account
gcloud projects add-iam-policy-binding $PROJECT --member=serviceAccount:my-account@$PROJECT.iam.gserviceaccount.com --role=roles/bigquery.admin
gcloud iam service-accounts keys create key.json --iam-account=my-account@$PROJECT.iam.gserviceaccount.com
export GOOGLE_APPLICATION_CREDENTIALS=key.json

# create script
cat << EOF > classify-text.py
from google.cloud import storage, language, bigquery

# Set up our GCS, NL, and BigQuery clients
storage_client = storage.Client()
nl_client = language.LanguageServiceClient()
# TODO: replace $PROJECT with your project name below
bq_client = bigquery.Client(project='$PROJECT')

dataset_ref = bq_client.dataset('news_classification_dataset')
dataset = bigquery.Dataset(dataset_ref)
table_ref = dataset.table('article_data')
table = bq_client.get_table(table_ref)

# Send article text to the NL API's classifyText method
def classify_text(article):
        response = nl_client.classify_text(
                document=language.Document(
                        content=article,
                        type_=language.Document.Type.PLAIN_TEXT
                )
        )
        return response


rows_for_bq = []
files = storage_client.bucket('qwiklabs-test-bucket-gsp063').list_blobs()
print("Got article files from GCS, sending them to the NL API (this will take ~2 minutes)...")

# Send files to the NL API and save the result to send to BigQuery
for file in files:
        if file.name.endswith('txt'):
                article_text = file.download_as_string()
                nl_response = classify_text(article_text)
                if len(nl_response.categories) > 0:
                        rows_for_bq.append((str(article_text), nl_response.categories[0].name, nl_response.categories[0].confidence))

print("Writing NL API article data to BigQuery...")
# Write article text + category data to BQ
errors = bq_client.insert_rows(table, rows_for_bq)
assert errors == []
EOF

# run the script
python3 classify-text.py