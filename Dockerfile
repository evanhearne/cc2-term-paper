FROM golang:1.23-alpine AS builder
WORKDIR /app

# Copy and download dependencies
COPY go.mod go.sum ./
RUN go mod tidy

# Copy source code
COPY . .

# Build the application
RUN go build -o main .

# Create a small final image
FROM alpine:latest
WORKDIR /root/

# Copy the compiled binary from the builder stage
COPY --from=builder /app/main .

# Expose the application's port
EXPOSE 8080

# Run the application
CMD ["./main"]