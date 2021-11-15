# 19 - 使用 Web Container 設定

4.4. Launching from a web application
Spring Batch is a lightweight framework that can live in a simple Spring application context. Here, we look at configuring a Spring Batch environment in a web application. This makes Spring Batch available at any time; there’s no need to spawn a dedicated Java process to launch a job. We can also embed a Java scheduler in the same web application context and become independent of any system schedulers. Figure 4.8 illustrates that a Spring application context can be contained in a web application. Note that the job beans can also use any available services, like data sources, data access objects, and business services.


Hosting Spring Batch in a web application is convenient, but what about pushing this architecture further and triggering jobs through HTTP requests? This is useful when an external system triggers jobs and that system cannot easily communicate with the Spring Batch environment. But before we study how to use HTTP to trigger jobs, let’s see how to configure Spring Batch in a web application.

4.4.1. Embedding Spring Batch in a web application
The Spring Framework provides a servlet listener class, the ContextLoaderListener, that manages the application context’s lifecycle according to the web application lifecycle. The application context is called the root application context of the web application. You configure the servlet listener in the web.xml file of the web application, as shown in the following listing.

4.4.2. Launching a job with an HTTP request
Imagine that you deployed your Spring Batch environment in a web application, but a system scheduler is in charge of triggering your Spring Batch jobs. A system scheduler like cron is easy to configure, and that might be what your administration team prefers to use. But how can cron get access to Spring Batch, which is now in a web application? You can use a command that performs an HTTP request and schedule that command in the crontab! Here’s how to perform an HTTP request with a command-line tool like wget:

## 參考
* https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/job.html#runningJobsFromWebContainer
* https://livebook.manning.com/book/spring-batch-in-action/chapter-4/197