# 12 - Control Step Flow
到目前為止，批次處理作業中都只有一個 Step，假如今天想要先做 `Tasklet` 再跑一般的 Step，或是有多個必須連續處理的邏輯，就可以使用 `FlowStep`。除了能夠串接多個 Step 流程外，還可以依照 Step 的執行結果來決定下面要執行的 Step，這意味著我們可以在第一個 Step 執行失敗後，有另一種處理的方式。

## Sequential Flow
Step Flow 中最簡單的順序流，作完 Step A 之後依序執行 Step B 跟 Step C。<br/>
![](/images/12-1.png)

使用的方法有 `start()` 及 `next()`，程式碼如下：

```java
@Bean
public Job job() {
    return this.jobBuilderFactory.get("job")
            .start(stepA())
            .next(stepB())
            .next(stepC())
            .build();
}
```
只有當每個 Step 被執行完成且狀態為 `COMPLETE` 才會往下繼續後面的 Step。

## Conditional Flow
上面 Sequential Flow 的狀況只會有兩種可能：
1. 執行成功，往下執行後續的 Step
2. 執行失敗，整個批次處理任務中止

要是想要在批次執行失敗的時候多加一個寄信給負責人的功能，就可以使用條件式的 Step。<br/>

![](/images/12-2.png)

###### Step 1
在修改之前，先在 `pom.xml` 加入用來發送 mail 的依賴 [spring-boot-starter-mail](https://mvnrepository.com/artifact/org.springframework.boot/spring-boot-starter-mail/2.5.6)。
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-mail</artifactId>
</dependency>
```
<br/>

###### Step 2
接下來設定參數，不過在設定參數前要先到 Google 帳號產稱授權碼，相關流程可以參考這篇[建立應用程式使用密碼](https://polinwei.com/spring-boot-send-email-via-gmail/#google_vignette)。

```java
@Configuration
public class SendMailConfig {

    @Bean
    public JavaMailSender getJavaMailSender() {

        JavaMailSenderImpl mailSender = new JavaMailSenderImpl();
        mailSender.setHost("smtp.gmail.com");
    //		mailSender.setPort(465);
        mailSender.setPort(587);
        mailSender.setUsername(""); // 信箱
        mailSender.setPassword(""); // 申請的應用程式密碼

        Properties prop = mailSender.getJavaMailProperties();
        prop.put("mail.smtp.auth", "true");
        prop.put("mail.smtp.starttls.enable", "true");
        prop.put("mail.smtp.starttls.required", "true");
        prop.put("mail.protocol", "stmp");
        prop.put("mail.smtp.ssl.trust", "smtp.gmail.com");
        prop.put("mail.debug", "true");
    //		prop.put("mail.socketFactory.class", "javax.net.ssl.SSLSocketFactory");

        return mailSender;
    }
}
```
<br/>

###### Step 3
先在 JobConfig 中建立寄送成功、失敗 email 的 Step 與 Tasklet。由由於 `Tasklet` 的內容不多，沒有另外獨立出單獨的 class。

```
spring.batch.springBatchExample.job
  |--DbReaderJobConfig.java // 修改
```

1. 注入 `JavaMailSender`。
    ```java
    /** 發送 email */
    @Autowired
    private  JavaMailSender mailSender;
    ```

2. 建立發送成功通知信件 Step
    ```java
    /**
    * 建立發送 success mail Step
    * @param itemReader
    * @param itemWriter
    * @param processor
    * @param transactionManager
    * @return
    */
    @Bean
    public Step sendSuccessEmailStep() {

        return stepBuilderFactory.get("Db001Step")
            .tasklet(new Tasklet() {
                
                @Override
                public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext)
                        throws Exception {

                    SimpleMailMessage mailMsg = new SimpleMailMessage();
                    mailMsg.setFrom("memorykghs@gmail.com");
                    mailMsg.setTo("memorykghs.iem01@nctu.edu.tw");
                    mailMsg.setSubject("Spring Batch 執行成功通知");
                    mailMsg.setText("成功啦!成功啦!!成功啦!!!");

                    mailSender.send(mailMsg);

                    return RepeatStatus.FINISHED;
                }
            })
            .build();
    }
    ```

3. 建立發送成功通知信件 Step
    ```java	
    /**
    * 建立發送 fail mail Step
    * @param itemReader
    * @param itemWriter
    * @param processor
    * @param transactionManager
    * @return
    */
    @Bean
    public Step sendFailEmailStep() {

        return stepBuilderFactory.get("Db001Step")
            .tasklet(new Tasklet() {
                
                @Override
                public RepeatStatus execute(StepContribution contribution, ChunkContext chunkContext)
                        throws Exception {

                    SimpleMailMessage mailMsg = new SimpleMailMessage();
                    mailMsg.setFrom("memorykghs@gmail.com");
                    mailMsg.setTo("memorykghs.iem01@nctu.edu.tw");
                    mailMsg.setSubject("Spring Batch 執行失敗通知");
                    mailMsg.setText("批次執行失敗通知測試");

                    mailSender.send(mailMsg);

                    return RepeatStatus.FINISHED;
                }
            })
            .build();
    }
    ```
<br/>

###### Step 4
最後同樣在 JobConfig 中建立 Step flow。

```
spring.batch.springBatchExample.job
  |--DbReaderJobConfig.java // 修改
```

```java
/**
 * 建立 Job
 * 
 * @param step
 * @return
 */
@Bean
public Job dbReaderJob(@Qualifier("Db001Step") Step step) {
    return jobBuilderFactory.get("Db001Job")
            .preventRestart()
            .start(step)
            .on("COMPLETED").to(sendSuccessEmailStep()) // 源頭是 Reader Step，成功發送信件
            .from(step).on("FAILED").to(sendFailEmailStep()) // 源頭也是 Reader Step，失敗也發送信件
            .end() // 表示 Step flow 結束
            .listener(new Db001JobListener())
            .build();
}
```
<br/>


> 範例：[Spring-Batch-Example feature/stepFlow](https://github.com/memorykghs/Spring-Batch-Example/tree/feature/stepFlow)

整理一些比較常用的 API 及相關功能：
| 方法 | 說明 | 
| --- | --- |
| `start(Step step)` | 傳入一個 Step，然後回傳 `StepBuilder` 物件，當後面沒有接其他 flow 相關的方法時，代表要執行的唯一 Step；在 Step flow 中則代表 Step 的源頭。 | 
| `on(String pattern)` | 傳入 String 型別的物件，在過程中會依照給予的條件判斷當前步驟的執行結果要往哪個分支進行下去。其他比對的特殊規則可以參考[官網](https://docs.spring.io/spring-batch/docs/current/reference/html/step.html#conditionalFlow)。 | 
| `to(Step step)` | 用來設定判斷後下一步要執行的 Step。 |
| `from(Step step)` | 從 `start()` 方法的 Step 註冊另外一條分支，並設定要執行的 Step。 |

大致的流程如下圖。<br/>
![](/images/12-3.png)

## Batch Status 與 Exit Status
在配置條件式的 Job 時，需要理解 `BatchStatus` 和 `ExitStatus` 之間的區別。

#### BatchStatus
`BatchStatus` 是一個 Enum，它是 `JobExecution` 和 `StepExecution` 的屬性，Spring Batch 框架使用它來記錄 `Job` 或 `Step` 的狀態。

`BatchStatus` 的值有以下幾種：
* `COMPLETED`
* `STARTING`
* `STARTED`
* `STOPPING`
* `STOPPED`
* `FAILED`
* `ABANDONED`
* `UNKNOWN`
<br/>

`BatchStatus` 的屬性是不能被客製化的。

```java
...
.from(stepA()).on("FAILED").to(stepB())
...
```
像上面這段程式碼中，可能會覺得 `on()` 方法中是用 `BatchStatus` 的狀態來判斷 Step 是否成功。但實際上，它是 reference 到 `Step` 的 `ExitStatus`。
<br/>

#### ExitStatus
`ExitStatus` 代表的是 `Step` 執行完畢後的狀態。

上面的例子中，`Step` 執行失敗就要執行 Step B，在一般的情況下 `BatchStatus` 跟 `ExitStatus` 的狀態代碼會是一樣的，那這樣又為什麼需要 `BatchStatus` 呢?來看看以下例子：

```java
public class SkipCheckingListener extends StepExecutionListenerSupport {
    public ExitStatus afterStep(StepExecution stepExecution) {
        String exitCode = stepExecution.getExitStatus().getExitCode();
        if (!exitCode.equals(ExitStatus.FAILED.getExitCode()) &&
              stepExecution.getSkipCount() > 0) {
            return new ExitStatus("COMPLETED WITH SKIPS");
        }
        else {
            return null;
        }
    }
}
```

在 `StepExecutionListener` 增加一些判斷邏輯，首先確認 `Step` 執行成功、在來判斷 skip 的次數是否大於 0，如果滿足條件的話，就回傳一個自訂的 `ExitStatus`。在註冊 Step 的流程時，就可以運用自訂的退出代碼來執行不同的 Step。

```java
@Bean
public Job job() {
    return this.jobBuilderFactory.get("job")
        .start(step1()).on("FAILED").end()
        .from(step1()).on("COMPLETED WITH SKIPS").to(errorPrint1())
        .from(step1()).on("*").to(step2())
        .end()
        .build();
}
```

## 停止 Step
要結束 Step Flow 的方式有兩種：`end()` 以及 `fail()`，或是使用 `stopAndRestart()`，這邊只會介紹前兩種。

#### Ending a Step
`end()` 方法用來結束某個條件流的 `Step`。如果某個業務邏輯需要，狀況 A 時執行兩個 Step，狀況則執行 3 個 Step，那麼我們就可以使用 `end()` 主動結束，範例如下：

```java
@Bean
public Job job() {
    return this.jobBuilderFactory.get("job")
        .start(step1())
        .next(step2())
        .on("FAILED").end()
        .from(step2()).on("*").to(step3())
        .end()
        .build();
}
```
![](/images/12-4.png)

* 不管走哪一條分支，只要批次執行完畢且狀態為 `COMPLETED`，就不能重新啟動。
* `end()` 方法中也可以指定要退出的狀態值，未指定的情況下狀態預設為 `COMPLETED`。
<br/>

#### Failing a Step
用來讓一個 Step 執行失敗 ( 狀態為 `FAILED` )，跟使用 `end()` 不一樣的地方是，失敗的 Job 可以被重啟。範例如下：

```java
@Bean
public Job job() {
    return this.jobBuilderFactory.get("job")
        .start(step1())
        .next(step2()).on("FAILED").fail()
        .from(step2()).on("*").to(step3())
        .end()
        .build();
}
```

## 參考
* https://docs.spring.io/spring-batch/docs/current/reference/html/step.html#controllingStepFlow

###### spring-boot-starter-mail
* https://www.baeldung.com/spring-email
* https://morosedog.gitlab.io/springboot-20190415-springboot27/
* https://polinwei.com/spring-boot-send-email-via-gmail/
* https://www.gushiciku.cn/pl/2Md9/zh-tw
