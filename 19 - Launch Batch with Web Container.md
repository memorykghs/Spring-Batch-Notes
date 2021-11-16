# 19 - 使用 Web Container 設定
Spring Batch 是一個可以依附在 Spring 應用程式環境的輕量級框架，表示 Spring Batch 可以在 Web 應用程式的環境下隨時使用，不需要特別使用 run as Java Application 啟動它，也可以在 Web 應用程式中使用 schedule 排程。

下圖代表了應用程式環境可以包含 Spring 執行環境。<br/>
![](/images/19-1.png)

讓 Spring Batch 依附在應用程式中非常方便，在進一步於這種架構下通過 Http 請求觸發批次作業前，我們先來看看如何在 Web 應用程式中配置 Spring Batch。

## 在 Web 應用程式中遷入 Spring Batch
Spring Framework 提供了一個 servlet 偵聽器類別 `ContextLoaderListener`，`ContextLoaderListener` 會根據 Web 應用程式的生命週期管理執行環境的生命週期。

預設情況下，`ContextLoaderListener` 類使用 Web 應用程式的 `WEB-INF` 目錄中的 `applicationContext.xml` 文件來建立應用程式的環境，裡面應包含 Spring Batch Infrastructure、Job、schedule ( 如果有 ) 和應用程序服務的配置。

![](/images/19-2.png)

4.4.2. Launching a job with an HTTP request
Imagine that you deployed your Spring Batch environment in a web application, but a system scheduler is in charge of triggering your Spring Batch jobs. A system scheduler like cron is easy to configure, and that might be what your administration team prefers to use. But how can cron get access to Spring Batch, which is now in a web application? You can use a command that performs an HTTP request and schedule that command in the crontab! Here’s how to perform an HTTP request with a command-line tool like wget:

![](/images/19-3.png)

## 參考
* https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/job.html#runningJobsFromWebContainer
* https://livebook.manning.com/book/spring-batch-in-action/chapter-4/197
* https://www.javainuse.com/spring/bootbatch
* https://stackoverflow.com/questions/53687925/how-to-launch-spring-batch-job-asynchronously
