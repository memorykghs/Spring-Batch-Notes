# 20 - 在 Web 應用程式中搭配 JobOperator 啟動

前面是嘗試直接使用 `JobLauncher` 啟動，現在搭配 `JobOperator` 來啟動。要啟動 Job 就要呼叫 `JobOperator` 的 `start()` 方法。<br/>

![](/images/20-1.png)

該方法需要傳入要啟動的 `JobName`，以及型別是字串的 `parameters` 參數，此參數可以為 `null`。而方法最後會回傳這次啟動的 `JobExecutionId`，有了 `JobExecutionId` 就可以在後面透過 `JobOperator` 去拿到跟這個 Job 相關的資訊。
```java
Long start(String jobName, String parameters) throws NoSuchJobException, JobInstanceAlreadyExistsException, JobParametersInvalidException;
```
<br/>

那接下來就把 Controller 中的方法修改一下。
```
spring.batch.springBatchPractice.controller
  |--BatchController.java // 修改
```

```java
@Api(tags = "Spring Batch Examples")
@RestController
public class BatchController {

    /** LOG */
    private static final Logger LOGGER = LoggerFactory.getLogger(BatchController.class);

    /** JobOperator */
    @Autowired
    private JobOperator jobOperator;

    @Autowired
    private JobRegistry jobRegistry;

    @Autowired
    private JobLauncher jobLauncher;

    /**
     * 使用 JobOperator
     * 
     * @return
     */
    @ApiOperation(value = "執行讀DB批次 (JobOperator)")
    @RequestMapping(value = "/dbReader001Job2", method = RequestMethod.POST)
    public String doDbReader001Job() {

        String summary = null;

        try {
            long jobExecutionId = jobOperator.start("Db001Job", null); // 取得 JobExecutionId
            summary = jobOperator.getSummary(jobExecutionId);

        } catch (NoSuchJobException | JobInstanceAlreadyExistsException | JobParametersInvalidException e) {
            e.printStackTrace();
        } catch (NoSuchJobExecutionException e) {
            e.printStackTrace();
        }

        return summary;
    }
}
```
上面我們讓 Controller 在執行後回傳這次執行的 Job 的 summary，回傳結果可以看到類似內容如下。<br/>

![](/images/20-2.png)

再打一次同樣的 Request，會發現 console 報錯，錯誤訊息如下：
```
Cannot start a job instance that already exists with name=Db001Job and parameters=null
```
![](/images/20-3.png)

因為有重複的參數且該 Job 的狀態已經執行完成，所以無法再次執行。所以如果 Job 是需要重複被執行的話，應該要使用 `JobOperator` 的 `startNextInstance()` 方法。修改程式如下：

```java
@Api(tags = "Spring Batch Examples")
@RestController
public class BatchController {

    /** LOG */
    private static final Logger LOGGER = LoggerFactory.getLogger(BatchController.class);

    /** JobOperator */
    @Autowired
    private JobOperator jobOperator;

    @Autowired
    private JobRegistry jobRegistry;

    @Autowired
    private JobLauncher jobLauncher;

    /**
     * 使用 JobOperator
     * 
     * @return
     */
    @ApiOperation(value = "執行讀DB批次 (JobOperator)")
    @RequestMapping(value = "/dbReader001Job2", method = RequestMethod.POST)
    public String doDbReader001Job() {

        String summary = null;

        try {
            long jobExecutionId = jobOperator.startNextInstance("Db001Job"); // 修改
            summary = jobOperator.getSummary(jobExecutionId);

        } catch (NoSuchJobException | JobParametersInvalidException e) {
            e.printStackTrace();
        } catch (NoSuchJobExecutionException e) {
            e.printStackTrace();
        } catch (JobParametersNotFoundException e) {
            e.printStackTrace();
        } catch (JobRestartException e) {
            e.printStackTrace();
        } catch (JobExecutionAlreadyRunningException e) {
            e.printStackTrace();
        } catch (JobInstanceAlreadyCompleteException e) {
            e.printStackTrace();
        } catch (UnexpectedJobExecutionException e) {
            e.printStackTrace();
        }

        return summary;
    }
}
```
那改成這樣之後可以把 `BatchCofig.java` 中，設定 Job 部分的 `incrementro()` 拿掉嗎?

```java
@Bean
public Job dbReaderJob(@Qualifier("Db001Step") Step step) {
    return jobBuilderFactory.get("Db001Job")
            .incrementer(new RunIdIncrementer()) // 可以砍掉嗎 >_<
            .start(step)
            .listener(new Db001JobListener())
            .build();
}
```

答案是不行，來看看 `startNextInstance()` 的敘述：<br/>
![](/images/20-5.png)

使用 `startNextInstance()` 的前提是依賴在 `JobParametersIncrementer` 物件上的，而這個東西會在設定 Job 的時候使用。

最後，相較於使用 `JobLauncher`，使用 `JobOperator` 啟動的好處在於，可以透過 `JobOperator` 查詢 Job 的狀態或是取得其他物件資訊，以下提供部分 `JobOperator` 的方法。<br/>

![](/images/20-4.png)