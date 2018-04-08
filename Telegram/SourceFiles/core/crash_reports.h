/*
This file is part of Telegram Desktop,
the official desktop application for the Telegram messaging service.

For license and copyright information please follow this link:
https://github.com/telegramdesktop/tdesktop/blob/master/LEGAL
*/
#pragma once

namespace CrashReports {

#ifndef TDESKTOP_DISABLE_CRASH_REPORTS

struct dump {
	~dump();
};
const dump &operator<<(const dump &stream, const char *str);
const dump &operator<<(const dump &stream, const wchar_t *str);
const dump &operator<<(const dump &stream, int num);
const dump &operator<<(const dump &stream, unsigned int num);
const dump &operator<<(const dump &stream, unsigned long num);
const dump &operator<<(const dump &stream, unsigned long long num);
const dump &operator<<(const dump &stream, double num);

#endif // TDESKTOP_DISABLE_CRASH_REPORTS

enum Status {
	CantOpen,
	LastCrashed,
	Started
};
Status Start();
Status Restart(); // can be only CantOpen or Started
void Finish();

void SetAnnotation(const std::string &key, const QString &value);
void SetAnnotationHex(const std::string &key, const QString &value);
inline void ClearAnnotation(const std::string &key) {
	SetAnnotation(key, QString());
}

// Remembers value pointer and tries to add the value to the crash report.
// Attention! You should call clearCrashAnnotationRef(key) before destroying value.
void SetAnnotationRef(const std::string &key, const QString *valuePtr);
inline void ClearAnnotationRef(const std::string &key) {
	SetAnnotationRef(key, nullptr);
}

void StartCatching();
void FinishCatching();

} // namespace CrashReports

namespace base {
namespace assertion {

inline void log(const char *message, const char *file, int line) {
	const auto info = QStringLiteral("%1 %2:%3"
	).arg(message
	).arg(file
	).arg(line
	);
	const auto entry = QStringLiteral("Assertion Failed! ") + info;

#ifdef LOG
	LOG((entry));
#endif // LOG

	CrashReports::SetAnnotation("Assertion", info);
}

} // namespace assertion
} // namespace base
