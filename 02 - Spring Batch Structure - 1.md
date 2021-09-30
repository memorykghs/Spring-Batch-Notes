# 02 - Spring Batch Structure - 1

## Spring Batch 架構大綱
| 物件 | 說明 |
| --- | --- |
Execution Context | 批次處理的執行環境，能夠將所需的餐處在處理任務的過程中進行傳遞
JobRepository | 提供處理任務的持久畫操作，儲存Job、Step執行過程中的狀態及結果
JobLauncher | 執行Job的入口，同時再啟動 Job 的時候可傳遞自定義參數
Job | Spring Batch 的一個批次處理過程，定義了批處理具體的執行邏輯，封裝整個批次處理過程的實例，由一個或多個Step組成
Step | 一個任務的具體的執行邏輯單位
Item | 一條資料記錄
ItemReader | 從資料來源讀取資料，讀取結束後會返回 `null`
ItemProcessor | 對資料進行處理，如資料清洗、轉換、過濾、校驗等，Spring Batch 提供一個 `chunk` 參數，每次任務會寫入一個 `chunk` 的數據，而 `chunk` 的數量取決於任務啟動時候的配置
ItemWriter | 寫入資料到指定目標
Chunk | 給定數量的Item集合，如讀取到chunk數量後，才進行寫操作
Tasklet | Step中具體執行邏輯，可重複執行

## Job
Job 是一個封裝整個批次處理的實體。跟其他的 Spring Project 一樣，Job 實體可以透過使用 XML 檔案或是 Java-based 的設定檔串接在一起，通常我們會稱這個檔案叫做 Job Configuration。而 Job 是整個流程最頂層的結構，示意圖如下：<br/>
![](/images/2-1.png)

> ![](/images/icon-info.png) 有一個定義好的 EndOfDay Job，執行時可以產生多個 Job Instance，Job Instance 又可以產生多個 Job Execution。

在 Spring Batch 中，Job 是一個裝有 Step 實例的一個簡單的容器。一個 Job 內可以有多個流程相關聯的 Step，並透過設定來配置這個 Job 下的所有 Step 的行為，例如可以重啟 ( restartability )。Job Configuration 包含：
  * 為 Job 實例命名，每個 Job 都有自己唯一的 ID
  * 定義 Step 實例以及其順序
  * Job 是否可以重新啟動

Spring Batch 提供了一個實作 Job interface 預設的 class ( `SimpleJob` )，並創建一些標準化的功能，用來建立 Job 實例。在 Java-based 的配置檔案中，可以用 Builder 來建立我們所需的 Job 實例，例：

```java
@Bean
public Job footballJob() {
    return this.jobBuilderFactory.get("footballJob")
                     .start(playerLoad())
                     .next(gameLoad())
                     .next(playerSummarization())
                     .build();
}
```

#### JobInstance
Job 執行時期會產生一個 JobInstance ( 作業實例 )，每一次啟動 Job 都會產生一個實例。JobInstance 的來源有2種可能：
  * 根據設置的 JobParameters 從 JobRepository 中獲取
  * 如果 Job Repository 中沒有拿到，則建立新的 JobInstance

Job Instance 之間需要靠 Job Parameters 區分。

#### JobParameters
上面提到 JobInstance 是靠不同的 JobParameters 來區分。如果同一個 Job，Job Name 相同，則 JobParameters 不相同；若是不同的 Job，則允許有相同的 Job Parameter。也就是說：
> JobInstance = Job + identifying JobParameters

<br/>

![](/images/2-3.png)

JobParameters 可以有4種不同的型別：`String`、`Date`、`Long` 或 `Double`。我們可以透過 cmd 來執行一個 Job，傳入的參數是 `schedule.date(date) = 2021/09/19`：
```cmd
java CommandLineJobRunner io.spring.EndOfDayConfiguration endOfDate schedule.date(date)=2021/09/19
```

CommandLineJobRunner 是 Spring Batch 提供的一個具有 `main` 方法的類別，指令內指定從 `io.spring.EndOfDayConfiguration` 這個有標註 `@Configuration` 的檔案中依照設定建立 Job；接下來的 `endOfDate` 則是 Job 的名稱，也就是產生 Job 的 `@Bean` 方法中設定。最後的 `schedule.date(date)=2021/09/19` 是傳入的 JobParameters。

另外，Spring Batch 框架也提供了通過 `JobParametersBuilder` 類別來建構參數：
```java
JobParameter jobParameter = (new JobParameterBuilder(jobParameter, jobExplorer)).getNextJobParameters(job).toJobParameters();
```

#### JobExecution
JobExecution 是一個概念，同一個 JobInstance 不同次的執行，不管成功或失敗都會產生不同的 JobExecution。假設 `EndOfDay` 這個 Job 在 2021-01-01 時執行失敗，再重新啟動一次，這時候就會產生新的 JobExecution，不過仍然是使用同一個 JobInstance。JobExecution 的儲存機制 ( storage mechanism ) 會記錄在執行時期相關的屬性，這些屬性會被持久化保存。

| Property | Type | Definition |
| --- | --- | --- |
| `status` | | 代表執行時期的狀態，當執行時狀態會是 `BatchStatus#STARTED`；如果執行失敗，則狀態為 `BatchStatus#FAILED`；執行成功且完成的畫則是 `BatchStatus#COMPLETED`。 |
| `startTime` | `java.util.Date` | 紀錄開始執行時當前的時間，在尚未執行前此欄位微空。 |
| `endTime` | `java.util.Date` | 紀錄執行完成的時間，不管執行結果成功或失敗。執行未完成前此欄位為空。 |
| `exitStatus` | | 執行結果的狀態，Spring Batch 會依照此結果將代碼回傳給呼叫的方法。當 Job 還沒有執行結束前此欄位為空。 |
| `createTime` | `java.util.Date` | 紀錄 JobExecution 第一次被持久化的時間。一個 Job 可能會沒有開始時間 ( `startTime` )，但一定會有被建立的時間 ( `createTime` )。 |
| `lastUpdated` | `java.util.Date` | 紀錄 JobException 最後一次被持久化的時間。如果 Job 從來沒有被執行過，此欄位為空。 |
| `executionContext` | | 一個存放在執行時期必要的使用者資料及屬性的環境。 | 
| `failureExceptions` |  | 紀錄 Job 失敗拋出的 Exception 的 List，可以用來除錯。 |

<br/>

假設 `EndOfDate` Job 在2021/01/01 的早上 9：00 開始執行，然後在 9：30 執行失敗，那麼這些資訊就會被存在 batch metadata table ( 以當日日期時間當作是 JobParameters )：
###### BATCH_JOB_INSTANCE
| JOB_INST_ID | JOB_NAME |
| --- | --- |
| 1 | EndOfDayJob |

###### BATCH_JOB_EXECUTION_PARAMS
| JOB_EXECUTION_ID | TYPE_CD | KEY_NAME | DATE_VAL | IDENTIFYING |
| --- | --- | --- | --- | --- |
| 1 | DATE | schedule.Date | 2021-01-01 00:00:00 | TRUE |

###### BATCH_JOB_EXECUTION
| JOB_EXEC_ID | JOB_INST_ID | START_TIME | END_TIME | STATUS |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2021-01-01 09:00 | 2021-01-01 09:30 | FAILED |

接續上面的狀況，因為第一天的 `EndOfDate` Job 執行失敗，所以第二天重新開始執行。但第二天同樣也有自己的批次要實行，此時當天的批次任務會被安排在重新執行前一天失敗的批次任務之後。也就是說第二天預計執行的 Job 會被安排在 9：30 之後開始。由於前一天執行的批次失敗，不會重新去取得 Job 的設定來啟動 Job，但是因為傳入的當日日期時間，是所以 2021/01/02 執行的 JobInstance 跟 2021/01/01 執行的是不同的實例。具體紀錄如下：
###### BATCH_JOB_INSTANCE
| JOB_INST_ID | JOB_NAME |
| --- | --- |
| 1 | EndOfDayJob |
| 2 | EndOfDayJob |

###### BATCH_JOB_EXECUTION_PARAMS
| JOB_EXECUTION_ID | TYPE_CD | KEY_NAME | DATE_VAL | IDENTIFYING |
| --- | --- | --- | --- | --- |
| 1 | DATE | schedule.Date | 2021-01-01 00:00:00 | TRUE |
| 2 | DATE | schedule.Date | 2021-01-01 00:00:00 | TRUE |
| 3 | DATE | schedule.Date | 2021-01-02 00:00:00 | TRUE |

###### BATCH_JOB_EXECUTION
| JOB_EXEC_ID | JOB_INST_ID | START_TIME | END_TIME | STATUS |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2021-01-01 09:00 | 2021-01-01 09:30 | FAILED |
| 2 | 1 | 2021-01-02 09:00 | 2021-01-02 09:30 | COMPLETED |
| 3 | 2 | 2021-01-02 09:31 | 2021-01-02 10:29 | COMPLETED |

## 參考
* https://docs.spring.io/spring-batch/docs/4.3.x/reference/html/domain.html#job
* https://www.docs4dev.com/docs/zh/spring-batch/4.1.x/reference/domain.html#domainLanguageOfBatch
* https://blog.csdn.net/whxjason/article/details/108817354
* https://blog.csdn.net/qq_40406929/article/details/118516843
* https://blog.csdn.net/guo_xl/article/details/83444983