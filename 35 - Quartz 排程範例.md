# Quartz 排程範例

* `QuartzConfiguration.java`
```java
package tw.com.cathaybk.pds.batch.configuration;

import java.util.TimeZone;

import org.quartz.CronScheduleBuilder;
import org.quartz.JobBuilder;
import org.quartz.JobDetail;
import org.quartz.Trigger;
import org.quartz.TriggerBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import tw.com.cathaybk.pds.batch.scheduling.BankCodeQuartzJob;
import tw.com.cathaybk.pds.batch.scheduling.FxRateQuartzJob;

@Configuration
public class QuartzConfiguration {
	
	@Bean
	public JobDetail bankCodeQuartzJob() {
		return JobBuilder.newJob(BankCodeQuartzJob.class)
				.withIdentity("bankCodeQuartzJob", "receiveQuartzGroup")
				.storeDurably()
				.build();
	}
	
	@Bean
	public JobDetail fxRateQuartzJob() {
		return JobBuilder.newJob(FxRateQuartzJob.class)
				.withIdentity("fxRateQuartzJob", "receiveQuartzGroup")
				.storeDurably()
				.build();
	}
	
	@Bean
	public Trigger bankCodeQuartzTrigger(
			@Value("${pds.scheduling.bank-code}") String cron) {
		return TriggerBuilder.newTrigger()
				.withIdentity("bankCodeQuartzTrigger", "receiveQuartzGroup")
				.forJob(bankCodeQuartzJob())
				.withSchedule(CronScheduleBuilder.cronSchedule(cron)
						.inTimeZone(TimeZone.getTimeZone("Asia/Taipei")))
				.build();
	}
	
	@Bean
	public Trigger fxRateQuartzTrigger(
			@Value("${pds.scheduling.fx-rate}") String cron) {
		return TriggerBuilder.newTrigger()
				.withIdentity("fxRateQuartzTrigger", "receiveQuartzGroup")
				.forJob(fxRateQuartzJob())
				.withSchedule(CronScheduleBuilder.cronSchedule(cron)
						.inTimeZone(TimeZone.getTimeZone("Asia/Taipei")))
				.build();
	}
}
```

* properties 參數
```properties
spring.quartz.job-store-type=memory
spring.quartz.properties.org.quartz.threadPool.threadCount=5
```
