# 03 - Spring Batch Structure - 1

## Spring Batch 架構大綱
| 物件 | 說明 |
| --- | --- |
Job | Spring Batch 的一個批次處理過程，定義了批處理具體的執行邏輯，封裝整個批次處理過程的實例，由一個或多個Step組成
Step | 一個任務的具體的執行邏輯單位
Item | 一條資料記錄
ItemReader | 從資料來源讀取資料，讀取結束後會返回 `null`
Chunk | 給定數量的 Item 集合，可以視為一個資料區塊，讀取到 chunk 數量後，才進行 write 操作
ItemProcessor | 對資料進行處理，如資料轉換、過濾、校驗等，每次任務會寫入一個 `chunk` ( 區塊 ) 的數據，而 `chunk` 的數量取決於任務啟動時候的配置
ItemWriter | 寫入資料到指定目標
Tasklet | Job 中的另一種執行邏輯，與 Step 不同，批次處理進行時只會被執行一次
Execution Context | 批次處理的執行環境，能夠將所需的參數在處理任務的過程中進行傳遞
JobRepository | 提供處理任務的持久化操作，儲存 Job、Step 執行過程中的狀態及結果
JobLauncher | 執行 Job 的入口，同時在啟動 Job 的時候可傳遞自定義參數

## Step
一個 Job 內可以有多個 Step，Step 是真正控制批次流程的物件。Step 內可以使用 ItemReader、ItemProcss、ItemWriter 等物件操作資料。而 Step 也有自己的 StepExecution。

#### StepExecution
定義有點像 JobExecution，不過只有當 Step 開始被真正執行時才會持久化。一個 StepExecution 會關連到一個 JobExecution。另外，StepExecution 會儲存許多當次運行 Step 相關的資料，並且持久化一些 Spring Batch 的屬性。<br/>
![](/images/3-1.png)

| Property | Type | Definition |
| --- | --- | --- |
| `status` | | 代表執行時期的狀態，當執行時狀態會是 `BatchStatus#STARTED`；<br/>如果執行失敗，則狀態為 `BatchStatus#FAILED`；<br/>執行成功且完成的畫則是 `BatchStatus#COMPLETED`。 |
| `startTime` | `java.util.Date` | 紀錄開始執行時當前的時間，在尚未執行前此欄位微空。 |
| `endTime` | `java.util.Date` | 紀錄執行完成的時間，不管執行結果成功或失敗。執行未完成前此欄位為空。 |
| `exitStatus` | | 執行結果的狀態，Spring Batch 會依照此結果將代碼回傳給呼叫的方法。當 Step 還沒有執行結束前此欄位為空。 |
| `executionContext` | | 一個存放在執行時期必要的使用者資料及屬性的環境。 |
| `readCount` | | 紀錄實際上有多少筆資料被成功讀取。 |
| `writeCount` | | 紀錄實際上有多少筆資料被成功輸出 ( write )。 |
| `commitCount` |  | 紀錄多少交易在該次執行被 commit。 |
| `rollbackCount` |  | 紀錄多少交易在該次執行被 rollback。 |
| `readSkipCount` |  | 紀錄當讀取失敗並 skip 的次數。 |
| `processSkipCount` |  | 紀錄 process 執行失敗並 skip 的次數。 |
| `filterCount` |  | 紀錄被過濾的物件資料筆數。 |
| `writeSkipCount` |  | 紀錄執行 write 時失敗並 skip 的次數。 |

## ExecutionContext
ExecutionContext 是一個由 Spring Batch 框架持久化和控制的鍵值對 ( `key / value pair` ) 的集合，可以讓開發人員用來儲存 StepExecution 或 JobExecution 的持久化對象。restart 就是一個常見的例子，假設今天是從檔案中讀取資料，Spring Batch 框架會在 commit 之前定期保留 ExecutionContext 對象，這樣 ItemReader 在運行期間如果發生錯誤而停止，下次啟動就可以依照 ExecutionContext 內紀錄的狀態，從前一次停止的地方重新開始。

還有重要的一點是，當 Step 執行期間，只會存在一個 ExecutionContext，如果同時有多個 Job 被執行，那麼 ExecutionContext 的狀態會被影響，因為他們是共用同一個 keyspace。

```java
ExecutionContext ecStep = stepExecution.getExecutionContext();
ExecutionContext ecJob = jobExecution.getExecutionContext();
//ecStep does not equal ecJob
```
而上面的例子，`ecStep` 跟 `ecJob` 擁有不一樣的 ExecutionContext。每一批提交的資訊會保存在 Step 的 ExecutionContext；而每次執行的 Step 則是會被保存在 Job 的 ExecutionContext。

## JobRepository
JobRepository 是上述所有 ( 包含前一章 ) Stereotypes 的持久性機制，Spring Batch 框架提供 JobRepository 來儲存 Job 執行時期需要的數據 ( Job Instance、Job Execution、Job Parameters、Step Execution、Execution Context等 )。

它為 JobLauncher、Job 以及 Step 提供了 CRUD 的操，可以想像成當批次被執行時，Spring Batch 會從 JobRepository 中取得 JobExecution。執行過程中，StepExecution 和 JobExecution 實例將會被 JobRepository 持久化。

> ![](/images/icon-info.png) `@EnableBatchProcessing` 標住就是用來提供一個 JobRepository 作為自動配置的組件之一。

## JobLauncher
JobLauncher 是一個 interface，功能是啟動 Job。它可以定義一個可以接收 JobParameters 的方法來啟動 Job，如下：
```java
public interface JobLauncher {

    public JobExecution run(Job job, JobParameters jobParameters)
            throws JobExecutionAlreadyRunningException, JobRestartException,
                   JobInstanceAlreadyCompleteException, JobParametersInvalidException;
}
```

<font color="red">所以我們可以直接建立一個匿名類別出來執行 `run()` 方法：</font>
```java
ConfigurableApplicationContext context = SpringApplication.run(SpringBatchPracticeApplication.class, args);
Job job = context.getBean(JobRegistry.class).getJob(jobName);
context.getBean(JobLauncher.class).run(job, createJobParams());
```

## 參考
* https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/domain.html#job
* https://www.docs4dev.com/docs/zh/spring-batch/4.1.x/reference/domain.html#domainLanguageOfBatch
* https://blog.csdn.net/whxjason/article/details/108817354
* https://blog.csdn.net/qq_40406929/article/details/118516843
* https://blog.csdn.net/guo_xl/article/details/83444983
