package main

import (
    "context"
    "fmt"
    "io/ioutil"
    "net/http"
    "os/exec"
    "time"

    "github.com/aws/aws-lambda-go/events"
    "github.com/aws/aws-lambda-go/lambda"
)

func handler(ctx context.Context, request events.ALBTargetGroupRequest) (events.ALBTargetGroupResponse, error) {
    // Запуск Python HTTP сервера
    cmd := exec.Command("python3", "server-binary-v2.py")
    err := cmd.Start()
    if (err != nil) {
        return events.ALBTargetGroupResponse{StatusCode: 500}, fmt.Errorf("failed to start python server: %v", err)
    }
fmt.Print("waiting  python server start ")
    // Ожидание запуска сервера с проверкой каждые 10 миллисекунд и таймаутом 5 секунд
    timeout := time.After(5 * time.Second)
    ticker := time.NewTicker(10 * time.Millisecond)
   defer func() {
    fmt.Print("timeout start python")
    ticker.Stop()
}()

    for {
        select {
        case <-timeout:
            return events.ALBTargetGroupResponse{StatusCode: 500}, fmt.Errorf("timeout waiting for python server to start")
        case <-ticker.C:
            resp, err := http.Get("http://localhost:8080")
            if err == nil && resp.StatusCode == http.StatusOK {
                resp.Body.Close()
                goto ServerStarted
            }
        }
    }

ServerStarted:
    // Отправка оригинального запроса к Python серверу
    resp, err := http.Get("http://localhost:8080")
    if err != nil {
        return events.ALBTargetGroupResponse{StatusCode: 500}, fmt.Errorf("failed to send request to python server: %v", err)
    }
    defer resp.Body.Close()

    body, err := ioutil.ReadAll(resp.Body)
    if err != nil {
        return events.ALBTargetGroupResponse{StatusCode: 500}, fmt.Errorf("failed to read response from python server: %v", err)
    }

    // Возвращение ответа через Lambda
    return events.ALBTargetGroupResponse{
        StatusCode:        resp.StatusCode,
        StatusDescription: http.StatusText(resp.StatusCode),
        Body:              string(body),
    }, nil
}

func main() {
    lambda.Start(handler)
}