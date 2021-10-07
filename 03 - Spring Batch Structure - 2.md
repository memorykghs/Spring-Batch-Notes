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

資料表對應：
1. `BATCH_JOB_INSTANCE` &longleftrightarrow; `JobInstance`
2. `BATCH_JOB_EXECUTION_PARAMS` &longleftrightarrow; `JobExecution`
3. `BATCH_JOB_EXECUTION` &longleftrightarrow; `JobParameters`
4. `BATCH_STEP_EXECUTION` &longleftrightarrow; `StepExecution`
5. `BATCH_STEP_EXECUTION_CONTEXT` &longleftrightarrow; `ExecutionContext`
6. `BATCH_JOB_EXECUTION_CONTEXT` &longleftrightarrow; `ExecutionContext`

## Step
一個 Job 內可以有多個 Step，Step 是真正控制批次流程的物件。Step 內可以使用 ItemReader、ItemProcss、ItemWriter 等物件操作資料。而 Step 也有自己的 StepExecution，對應的表格是 `BATCH_STEP_EXECUTION`。

#### StepExecution
定義有點像 JobExecution，不過只有當 Step 開始被真正執行時才會持久化。一個 StepExecution 會關連到一個 JobExecution。另外，StepExecution 會儲存許多當次運行 Step 相關的資料，並且持久化一些 Spring Batch 的屬性。<br/>
![](/images/3-1.png)

###### BATCH_STEP_EXECUTION
| 屬性 | 說明 |
| --- | ---|
`STEP_EXECUTION_ID` | 主鍵。程式面可以透過 `StepExecution` 物件的 `getId()` 方法取得。
`VERSION` | 版本號
`STEP_NAME` | Step 的名稱，可以在使用 `StepBuilderFactory` 建立 Step 物件時設定。
`JOB_EXECUTION_ID` | 對應 `BATCH_JOB_EXECUTION` 表格的外來鍵。代表這個 StepExecution 屬於哪個 JobExecution。
`START_TIME` | 紀錄開始執行時當前的時間。
`END_TIME` | 紀錄執行完成的時間，不管執行結果成功或失敗。執行未完成前此欄位為空。
`STATUS` | 代表執行時期的狀態，當執行時狀態會是 `BatchStatus#STARTED`；如果執行失敗，則狀態為 `BatchStatus#FAILED`；執行成功且完成的畫則是 `BatchStatus#COMPLETED`。
`COMMIT_COUNT` | 紀錄執行期間已提交的事務的次數
`READ_COUNT` | 執行過程中成功讀取的項目數量
`FILTER_COUNT` | 執行過程中過濾的項目數量
`WRITE_COUNT` | 執行過程中寫入和提交的項目數量
`READ_SKIP_COUNT` | 執行過程中跳過不讀取的項目數量
`WRITE_SKIP_COUNT` | 執行過程中跳過不寫入的項目數量
`PROCESS_SKIP_COUNT` | 執行過程中 Process 跳過的項目數量
`ROLLBACK_COUNT` | 執行期間 rollback 的次數，包括每次重試 ( retry ) 及跳過 ( skip ) 造成的 rollback 次數。
`EXIT_CODE` | 執行結果的狀態，Spring Batch 會依照此結果將代碼回傳給呼叫的方法。當 Step 還沒有執行結束前此欄位為空。
`EXIT_MESSAGE` | 作業執行跳出的詳細的描述。再失敗的情況下，會包含失敗例外的 stackTrace。
`LAST_UPDATED` | 代表上一次執行的時間。
<br/>

![](/images/3-2.png)

## ExecutionContext
ExecutionContext 是一個由 Spring Batch 框架持久化和控制的鍵值對 ( `key / value pair` ) 的集合，可以讓開發人員用來儲存 StepExecution 或 JobExecution 的持久化對象。restart 就是一個常見的例子。Spring Batch 會將 ExecutionContext 的內容持久化到資料庫中，以方便後續重起的時候，直接從資料庫中讀取資訊，並且讓批次任務從失敗的地方繼續執行。對應的表為 `BATCH_STEP_EXECUTION_CONTEXT` 和 `BATCH_JOB_EXECUTION_CONTEXT`。
<br/>

###### BATCH_STEP_EXECUTION_CONTEXT
| 屬性 | 說明 |
| --- | ---|
`STEP_EXECUTION_ID` | 關連到 `BATCH_STEP_EXECUTION` 表格的外鍵，可以對應到多個 StepExecution。
`SHORT_CONTEXT` | `SERIALIZED_CONTEXT` ( 字串 )
`SERIALIZED_CONTEXT` | 整格執行環境序列化
<br/>

![](/images/3-4.png)

###### BATCH_JOB_EXECUTION_CONTEXT
| 屬性 | 說明 |
| --- | ---|
`JOB_EXECUTION_ID` | 關連到 `BATCH_JOB_EXECUTION` 表格的外鍵，可以對應到多個 JobExecution。
`SHORT_CONTEXT` | `SERIALIZED_CONTEXT` ( 字串 )
`SERIALIZED_CONTEXT` | 整格執行環境序列化
<br/>

![](/images/3-5.png)

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

## ItemReader
ItemReader 是一個定義讀資料類別行為的 interface，當資料讀取結束會回傳 `null`，來告訴後續操作讀取結束。ItemReader 在讀取資料的過程中是不能對資料進行操作的。Spring Batch 為 ItemReader 提供非常多的實現類，例如 JdbcPagingItemReader、JdbcCursorItemReader 等等。ItemReader 支援讀入的資料來源也很多，包括各種型別的資料庫、檔案、資料流等等。ItemReader 的類型可以參考 [ItemReader 列表](https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/appendix.html#listOfReadersAndWriters)。

## ItemWriter
相對於 ItemReader，ItemWriter 主要針對批次處理資料區塊的輸出定義行為。ItemWriter 寫資料的單位是可以設定的，可以一次寫一筆資料，也可以一次寫一個 chunk 的資料。然而跟 ItemReader 相同，ItemWriter 無法對接收的資料進行資料操作或處理。

Spring Batch 為 ItemWriter 提供許多實現類，當然我們也可以去自定義 ItemWriter。其他類型的 ItemWriter 可以參考官網提供的 [ItemWriter 列表](https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/appendix.html#itemWritersAppendix)。

## ItemProcessor
ItemProcessor 主要是對毒入的資料進行處理，當 ItemReader 讀到一條資料後，在 ItemWriter 尚未寫入這條資料之前，可以透過 ItemProcessor 提供的功能對資料進行業務邏輯處理。如果處理的過程中，該筆資料不應該繼續往下一個步驟 ( 通常是 ItemWriter ) 傳遞，就回傳 `null`。

## Spring Batch 表格相關
前一章以及本章提到的一些用於紀錄狀態的表格結構 UML 如下：<br/>
![](/images/3-3.png)

表格可以手動新增或是透過 properties 設定自動在 DB 產生。

#### 手動新增
1. 可以在本機以下的路徑找到使用的 Spring Batch Core 的版本。
   ```
   C:\Users\user\.m2\repository\org\springframework\batch\spring-batch-core\4.2.0.RELEASE
   ```
   <br/>
   
   ![](/images/3-4.png)

2. 在該 jar 檔上按右鍵，選擇以 WinRAR 或同類型的應用程式開啟。

   ![](/images/3-5.png)

3. 依照以下路徑進入資料夾，會看到該層下有給不同 DB 使用的 SQL schema 檔案。
   ```
   org/srpingframework/batch/core
   ```
   ![](/images/3-6.png)

4. 選擇相對應的 DB 打開檔案就會有 SQL 了。

#### 透過 properties 設定
在 `application.properties` 檔案中設定。
```properties
# 不自動產生
spring.batch.initialize-schema=never

# 自動產生
spring.batch.initialize-schema=always
```

## 參考
* https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/domain.html#job
* https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/schema-appendix.html#metaDataSchema
* https://www.docs4dev.com/docs/zh/spring-batch/4.1.x/reference/domain.html#domainLanguageOfBatch
* https://blog.csdn.net/whxjason/article/details/108817354
* https://blog.csdn.net/qq_40406929/article/details/118516843
* https://blog.csdn.net/guo_xl/article/details/83444983
* http://www.4k8k.xyz/article/huanyuminhao/110187739

