FROM golang:1.26

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -o server .

CMD ["./server"]


FROM alpine:3.13

WORKDIR /app

COPY --from=builder /app/main .

COPY .env .
COPY wait-for.sh .

RUN chmod +x wait-for.sh

EXPOSE 8080

CMD [ "/app/main" ]