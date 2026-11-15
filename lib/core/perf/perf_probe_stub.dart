void publishPerfSnapshot(Map<String, double> snapshot) {}

void registerPerfReset(void Function() onReset) {}

void clearPerfProbe() {}

void registerBenchScroll(Map<String, Object> Function()? readScroll) {}

void recordPerfMark(String name) {}
