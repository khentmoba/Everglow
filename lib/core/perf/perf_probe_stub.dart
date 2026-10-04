/// Off-web there is no console to publish to; the overlay is the only reader.
void publishPerfSnapshot(Map<String, double> snapshot) {}

void registerPerfReset(void Function() onReset) {}

void clearPerfProbe() {}

void registerBenchScroll(Map<String, Object> Function()? readScroll) {}
