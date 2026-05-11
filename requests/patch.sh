#!/bin/bash

curl -X PATCH http://localhost:8080/albums/1 -H "Content-Type: application/json" -d '{
  "title": "Updated Title",
  "artist": "Updated Artist",
  "price": 150
}'
