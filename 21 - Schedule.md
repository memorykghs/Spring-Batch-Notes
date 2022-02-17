# 21 - Schedule
首先一樣要在 Application 上加上 `@EnableScheduling`。

```java
@SpringBootApplication
@EnableBatchProcessing
@EnableRetry
@EnableScheduling
public class SpringBatchExmapleApplication {

    private static final Logger LOGGER = LoggerFactory.getLogger(SpringBatchExmapleApplication.class);

    public static void main(String[] args) {
        ...
        ...
    }
}
```

建立一個排成的 class `ScheduleTask`，並使用 `@Component` 註冊。

* `BatchSchedule.java`
```java
@Component
public class BatchSchedule {

	/** jobRegistry */
	@Autowired
	private JobRegistry jobRegistry;

	/** jobLoauncher */
	@Autowired
	private JobLauncher jobLauncher;

	/** beanFactory */
	@Autowired
	private BeanFactory beanFactory;

	@Async
	@Scheduled(cron = "0 0 8 * * ?")
	public void readFromDb() throws Exception {
		String jobName = "readFromDbJob";
		Job job = jobRegistry.getJob(jobName);
		jobLauncher.run(job， parametersBuilder("readFromDbJob").toJobParameters());
	}
	
	/**
	 * 產生 JobParameter
	 * @param jobName
	 * @return
	 */
	private JobParametersBuilder parametersBuilder(String jobName) {
		return new JobParametersBuilder()
				.addString("sameParameter"， "string")
				.addDate("date"， new Date());
	}
}
```
由於批次任務都是要透過 JobRegistry 與 JobLauncher 帶起來的，所以也是要 `@Autowired`。

`@Schedule` 提供以下屬性使用：

* `cron` - cron 表示式，指定任務在特定時間執行
* `fixedDelay` - 表示上一次任務執行完成後多久再次執行，型別為 long，單位 ms ( 毫秒 )
* `fixedDelayString` - 與 `fixedDelay` 功能一樣，只是引數型別變為 String
* `fixedRate` - 表示按一定的頻率執行任務，引數型別為 long，單位ms
* `fixedRateString` - 與 fixedRate 的功能一樣，只是將引數型別變為 String
* `initialDelay` - 表示延遲多久再第一次執行任務，引數型別為long，單位ms
* `initialDelayString` - 與 `initialDelay` 的功能一樣，只是將引數型別變為 String
* `zone` - 時區，預設為當前時區

## Cron 表示式定義
Cron 表示式是一個字串，是由空格隔開的 6 或 7 個域組成，每一個域對應一個含義（秒 分 時 每月第幾天 月 星期 年）其中年是可選欄位。

```
┌───────────── second (0-59)
│ ┌───────────── minute (0-59)
│ │ ┌───────────── hour (0-23)
│ │ │ ┌───────────── day of the month (1-31)
│ │ │ │ ┌───────────── month (1-12) (or JAN-DEC)
│ │ │ │ │ ┌───────────── day of the week (0-7)
│ │ │ │ │ │          (0 or 7 is Sunday， or MON-SUN)
│ │ │ │ │ │
* * * * * *
```

#### 特殊自源含意
* `*` : 匹配該域的任意值，比如在秒數的位置出現 `*`， 就表示每秒都會觸發事件
<br/>

* `?` :
  * 只能用在每月第幾天和星期兩個位置。
  * 表示不指定值，當 2 個子表示式其中之一被指定了值以後，為了避免衝突，需要將另一個子表示式的值設為 `?`
<br/>

* `–` : 表示範圍，例如在分鐘的位置使用 5-20，表示從 5 分到 20 分鐘每分鐘觸發一次
<br/>

* `/` : 表示起始時間開始觸發，然後每隔固定時間觸發一次，例如在分鐘的位置使用 5/20，則意味著 5 分，25 分，45 分，分別觸發一次
<br/>

* `，` : 表示列出列舉值。例如：在分鐘的位置使 5，20，則意味著在 5 和 20 分時觸發一次
<br/>

* `L` : 表示最後，只能出現在星期和每月第幾天域，如果在星期域使用 1L，意味著在最後的一個星期日觸發 
<br/>

* `W` : 表示有效工作日 ( 週一到週五 )，只能出現在每月第幾日域，系統將在離指定日期的最近的有效工作日觸發事件。注意一點，W 的最近尋找不會跨過月份。<br/>
 
* `LW` : 這兩個字元可以連用，表示在某個月最後一個工作日，即最後一個星期五
<br/>

* `#` : 用於確定每個月第幾個星期幾，只能出現在每月第幾天域。例如在 1#3，表示某月的第三個星期日

## 參考
* https://polinwei.com/spring-boot-scheduling-tasks/
* https://www.gushiciku.cn/pl/gDvh/zh-tw