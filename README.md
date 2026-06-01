# aws-traffic-cam



\# AWS Traffic Cam



A real-time traffic monitoring web application built on AWS, streaming live webcam footage from a Raspberry Pi with dynamic visual effects driven by weather and time-of-day data.



\## Live Demo

\[https://d14colzsdu99fx.cloudfront.net](https://d14colzsdu99fx.cloudfront.net)



\## Architecture



!\[Architecture](architecture.png)



\- \*\*Raspberry Pi 3\*\* captures live video via USB webcam and pushes an RTMP stream using ffmpeg

\- \*\*Amazon IVS\*\* ingests the RTMP stream and serves it as HLS for low-latency playback

\- \*\*AWS Lambda\*\* runs on a 1-minute schedule via EventBridge, fetches weather data from OpenWeatherMap, computes traffic level based on time of day, and writes the current state to DynamoDB

\- \*\*Amazon DynamoDB\*\* stores the current traffic state as a single item updated every minute

\- \*\*API Gateway\*\* exposes a REST endpoint (`GET /state`) that the frontend polls every 60 seconds

\- \*\*S3 + CloudFront\*\* host the static frontend and serve it over HTTPS globally

\- \*\*AWS Secrets Manager\*\* stores all third-party API keys securely

\- \*\*CloudFormation\*\* defines all infrastructure as code for reproducible deployments



\## Visual States



| State | Trigger | Effect |

|-------|---------|--------|

| Low traffic | Outside rush hours | Green border |

| Medium traffic | 9am–5pm | Amber border + warm tint |

| High traffic | 7–9am or 5–8pm | Red border + shake animation + red tint |

| Rain | OpenWeatherMap weather condition | Blue/desaturated overlay |

| Night | Local time 10pm–6am | Dimmed brightness |



\## Tech Stack



\- AWS IVS, Lambda, DynamoDB, API Gateway, S3, CloudFront, EventBridge, Secrets Manager, IAM

\- Python 3.12 (Lambda)

\- ffmpeg (Raspberry Pi stream)

\- Vanilla JS + CSS animations (frontend)

\- CloudFormation (IaC)



\## Project Structure

aws-traffic-cam/

├── pi/

│   └── stream.sh          # ffmpeg stream script for Raspberry Pi

├── frontend/

│   ├── index.html

│   ├── styles.css

│   └── app.js

├── lambda/

│   └── lambda\_function.py

└── infrastructure/

└── template.yaml      # CloudFormation template



\## Deployment



\### Prerequisites

\- AWS account with IAM user configured

\- Raspberry Pi with USB webcam and ffmpeg installed

\- OpenWeatherMap API key



\### Deploy infrastructure

```bash

aws cloudformation deploy \\

&#x20; --template-file infrastructure/template.yaml \\

&#x20; --stack-name aws-traffic-cam \\

&#x20; --parameter-overrides OpenWeatherApiKey=YOUR\_KEY \\

&#x20; --capabilities CAPABILITY\_NAMED\_IAM

```



\### Start the stream

```bash

\# On the Raspberry Pi

./pi/stream.sh

```



\## Notes



\- TomTom Traffic Flow API does not have coverage for Asunción, Paraguay. Traffic level is currently simulated based on typical rush hour patterns. The architecture fully supports swapping in any traffic API.

\- Stream is manually started on the Pi. A future improvement would be a systemd service to auto-start on boot.



\## Author

Luis — Cloud Engineer in training | AWS Solutions Architect Associate (in progress)

