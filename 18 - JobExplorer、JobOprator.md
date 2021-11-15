# 18 - JobExplorer、JobOprator

到目前為止，只有提到 `JobLauncher` 和 `JobRepository` 介面，這兩個介面實作的物件可以用來啟動批次，並提供對特定領域對象的 CRUD 操作。<br/>

![](/images/18-1.png) 

`JobLauncher` 物件會用 `JobRepository` 提供的功能建立新的 `JobExecution` 物件並執行。`Job` 跟 `Step` 實例也會在執行過程中使用 `JobRepository` 針對同一個執行環境更新執行狀態。

這樣的啟動模式對於擁有數十甚至上百個批次的系統來說，就相對複雜而且不切實際，因為每次啟動一個批次作業，都要重新建立應用程式的環境。Spring Batch 框架針對這接更進階的需求，在啟動與設定的方式上有些許不同。<br/>

![](/images/18-2.png)

## JobExplorer
`JobExplorer` 和 `JobOperator` 介面常常被拿出來一起討論，因為它們提供一些額外的方法供查詢和控制 meta-data。`JobExplorer` 可以對在 `JobRepository` 內當前的執行環境查詢，不過是 read-only 版本的 `JobRepository`，沒有 CUD 的操作，其介面如下：
```java
public interface JobExplorer {

    List<JobInstance> getJobInstances(String jobName, int start, int count);

    JobExecution getJobExecution(Long executionId);

    StepExecution getStepExecution(Long jobExecutionId, Long stepExecutionId);

    JobInstance getJobInstance(Long instanceId);

    List<JobExecution> getJobExecutions(JobInstance jobInstance);

    Set<JobExecution> findRunningJobExecutions(String jobName);
}
```

也可以自訂 `JobExplorer` 的一些屬性：
```java
...
// This would reside in your BatchConfigurer implementation
@Override
public JobExplorer getJobExplorer() throws Exception {
	JobExplorerFactoryBean factoryBean = new JobExplorerFactoryBean();
	factoryBean.setDataSource(this.dataSource);
	return factoryBean.getObject();
}
...
```

![](/images/icon-bird-3.png) **補充**：
`JobRepository` 是可以根據不同 DataSource 的 prefix 去定義的，同樣的 `JobExplorer` 也需要設定。
```java
...
// This would reside in your BatchConfigurer implementation
@Override
public JobExplorer getJobExplorer() throws Exception {
	JobExplorerFactoryBean factoryBean = new JobExplorerFactoryBean();
	factoryBean.setDataSource(this.dataSource);
	factoryBean.setTablePrefix("SYSTEM."); // set prefix
	return factoryBean.getObject();
}
...
```

## JobOperator
如之前前面提到的 `JobRepository` 提供了對 meta-data 的一些操作，`JobExplorer` 則是 `JobRepository` read-only 的版本。`JobOperator` 在監控批次任務非常有用，例如控制它們 restart、stop 或是 summarize 批次任務的結果等等。以下為 `JobOperator` 的介面：

```java
public interface JobOperator {

    List<Long> getExecutions(long instanceId) throws NoSuchJobInstanceException;

    List<Long> getJobInstances(String jobName, int start, int count)
          throws NoSuchJobException;

    Set<Long> getRunningExecutions(String jobName) throws NoSuchJobException;

    String getParameters(long executionId) throws NoSuchJobExecutionException;

    Long start(String jobName, String parameters)
          throws NoSuchJobException, JobInstanceAlreadyExistsException;

    Long restart(long executionId)
          throws JobInstanceAlreadyCompleteException, NoSuchJobExecutionException,
                  NoSuchJobException, JobRestartException;

    Long startNextInstance(String jobName)
          throws NoSuchJobException, JobParametersNotFoundException, JobRestartException,
                 JobExecutionAlreadyRunningException, JobInstanceAlreadyCompleteException;

    boolean stop(long executionId)
          throws NoSuchJobExecutionException, JobExecutionNotRunningException;

    String getSummary(long executionId) throws NoSuchJobExecutionException;

    Map<Long, String> getStepExecutionSummaries(long executionId)
          throws NoSuchJobExecutionException;

    Set<String> getJobNames();
}
```

`JobOperator` 的介面綜合許多不同街口的方法，例如 `JobLauncher`、`JobRepository`、`JobExplorer`、和 `JobRegistry`。所以在 `BatchConfig` 中自訂 `JobOperator` 時必須依賴上面提到的實例物件。以下提供一個簡單設定 `SimpleJobOperator` 的範例：

```java
@Bean
public SimpleJobOperator jobOperator(JobExplorer jobExplorer, JobRepository jobRepository, JobRegistry jobRegistry) {

    SimpleJobOperator jobOperator = new SimpleJobOperator();

    jobOperator.setJobExplorer(jobExplorer);
    jobOperator.setJobRepository(jobRepository);
    jobOperator.setJobRegistry(jobRegistry);
    jobOperator.setJobLauncher(jobLauncher);

    return jobOperator;
}
```

## JobParametersIncrementer
原本使用 Application 自動帶起批次任務並執行，在 Application 中我們有建立一個建立一個方法，依照不同的 `JobName` 來決定要塞那些 `JobParamter` 進去，由 `JobLauncher` 啟動批次，以創造不同的 `JobInstance`。
```java
@SpringBootApplication
@EnableBatchProcessing
public class SpringBatchExmapleApplication {
    ...
    private static JobParameters createJobParams() {

        JobParametersBuilder builder = new JobParametersBuilder();
        builder.addDate("executeTime", Timestamp.valueOf(LocalDateTime.now()));

        return builder.toJobParameters();
    }
    ...
}
```
<br/>

跟由 `JobLauncher` 啟動批次不同，由 Web App 啟動批次的模式，不同的批次任務會在 Controller 中擁有不同的 url，所以彼此的參數不會干擾，這時候如果想要重啟或是在執行一次批次的話，會因為有相同的參數導致無法執行。這時候就可以使用 `JobParametersIncremente` 的 `startNextInstance()` 方法，強制產生新的 `JobInstance` 來執行。
```java
public interface JobParametersIncrementer {
    JobParameters getNext(JobParameters parameters);
}
```
<br/>

不過有個問題來啦~`JobParametersIncrementer` 實例有一個 `getNext()` 方法可產生下一個參數的實例並回傳。不過當加入的參數型別是 `Date`，那下一個參數應該是增加一天還是一週呢?這種情況下可以透過自訂 `JobParametersIncrementer` 撰寫遞增邏輯。
```java
public class SampleIncrementer implements JobParametersIncrementer {

    public JobParameters getNext(JobParameters parameters) {
        if (parameters==null || parameters.isEmpty()) {
            return new JobParametersBuilder().addLong("run.id", 1L).
        }
        long id = parameters.getLong("run.id",1L) + 1;
        return new JobParametersBuilder().addLong("run.id", id).
    }
}
``` 

而 `incrementer()` 本身可以定義在 Job 中或是
```java
@Bean
public Job footballJob() {
    return this.jobBuilderFactory.get("footballJob")
                .incrementer(sampleIncrementer())
                ...
                .build();
}
```

## 參考
* https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/job.html#queryingRepository

###### 梗圖來源
* [貓咪讚](https://home.gamer.com.tw/creationDetail.php?sn=4835194)