import json
import boto3
import urllib.request
from datetime import datetime, timezone

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('traffic-state')
secrets_client = boto3.client('secretsmanager')

LAT = -25.2911
LON = -57.5523

def get_secret():
    response = secrets_client.get_secret_value(SecretId='traffic-cam/api-keys')
    return json.loads(response['SecretString'])

def get_traffic():
    hour = datetime.now(timezone.utc).hour
    local_hour = (hour - 4) % 24
    if 7 <= local_hour < 9 or 17 <= local_hour < 20:
        return 'high'
    elif 9 <= local_hour < 17:
        return 'medium'
    else:
        return 'low'

def get_weather(api_key):
    url = f"https://api.openweathermap.org/data/2.5/weather?lat={LAT}&lon={LON}&appid={api_key}&units=metric"
    with urllib.request.urlopen(url) as response:
        data = json.loads(response.read())
    condition = data['weather'][0]['main'].lower()
    return condition

def get_time_of_day():
    hour = datetime.now(timezone.utc).hour
    local_hour = (hour - 4) % 24
    if 6 <= local_hour < 12:
        return 'morning'
    elif 12 <= local_hour < 18:
        return 'afternoon'
    elif 18 <= local_hour < 22:
        return 'evening'
    else:
        return 'night'

def lambda_handler(event, context):
    secrets = get_secret()
    traffic = get_traffic()
    weather = get_weather(secrets['OPENWEATHER_API_KEY'])
    time_of_day = get_time_of_day()

    table.put_item(Item={
        'stationId': 'main-street',
        'trafficLevel': traffic,
        'weather': weather,
        'timeOfDay': time_of_day,
        'updatedAt': datetime.now(timezone.utc).isoformat()
    })

    return {
    'statusCode': 200,
    'headers': {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET',
        'Content-Type': 'application/json'
    },
    'body': json.dumps({
        'trafficLevel': traffic,
        'weather': weather,
        'timeOfDay': time_of_day
    })
}

    