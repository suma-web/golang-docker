#!/bin/bash

curl -X POST http://localhost:8080/albums -H "Content-Type: application/json" -d '{
  "title": "Sample Title",
  "artist": "Sample Artist",
  "price": 100
}'
