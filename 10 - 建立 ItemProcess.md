# 10 - 建立 ItemProcess

前面只提到了 Reader 跟 Writer，如果想要在讀進來之後，寫出去之前多做一些業務邏輯的處理，就可以選擇使用 ItemProcess。

```java
public interface ItemProcessor<I, O> {

    O process(I item) throws Exception;
}
```
