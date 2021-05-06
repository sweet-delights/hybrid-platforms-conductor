package main

import (
    "fmt"
    "io/ioutil"
    "log"
    "net/http"
    "os"
)

const homepageEndPoint = "/"

// StartWebServer the webserver
func StartWebServer() {
    http.HandleFunc(homepageEndPoint, handleHomepage)
    port := os.Getenv("PORT")
    if len(port) == 0 {
        panic("Environment variable PORT is not set")
    }

    log.Printf("Starting web server to listen on endpoints [%s] and port %s",
        homepageEndPoint, port)
    if err := http.ListenAndServe(":"+port, nil); err != nil {
        panic(err)
    }
}

func handleHomepage(w http.ResponseWriter, r *http.Request) {
    urlPath := r.URL.Path
    log.Printf("Web request received on url path %s", urlPath)
    content, content_err := ioutil.ReadFile("/root/hello_world.txt")
    if content_err != nil {
        fmt.Printf("Failed to read message to display, err: %s", content_err)
    }
    _, write_err := w.Write(content)
    if write_err != nil {
        fmt.Printf("Failed to write response, err: %s", write_err)
    }
}

func main() {
    StartWebServer()
}
