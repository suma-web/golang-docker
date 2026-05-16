FROM golang:1.26 AS development

WORKDIR /app

RUN go install github.com/air-verse/air@latest

COPY go.mod go.sum ./
RUN go mod download

COPY . .


RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server .

CMD ["air", "-c", ".air.toml"]

FROM alpine:3.20 AS production

WORKDIR /app

RUN apk add --no-cache ca-certificates tzdata

COPY --from=development /app/server /app/server

EXPOSE 8080

CMD ["/app/server"]
