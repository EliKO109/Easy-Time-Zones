# Time Bridge Menu Bar for macOS

אפליקציית Menu Bar קטנה למק שממירה שעות בין המיקום שלך לבין מדינות / ערים אחרות.

## מה היא עושה
- מציגה את השעה הנוכחית אצלך בסרגל העליון
- מאפשרת להגדיר Home location, למשל San Antonio, Texas
- מאפשרת להוסיף ערים / מדינות להשוואה
- מאפשרת לדעת:
  - מה השעה עכשיו במדינה אחרת
  - מה תהיה השעה אצלך כשבמדינה אחרת השעה היא שעה מסוימת, למשל 08:00 בישראל
- מתחשבת אוטומטית ב-Daylight Saving Time דרך מערכת ה-Time Zone של macOS

## איך להפעיל
1. פתח Xcode
2. צור פרויקט חדש:
   - macOS
   - App
   - Interface: SwiftUI
   - Language: Swift
3. מחק את התוכן בקובץ הראשי של האפליקציה
4. הדבק את התוכן של `TimeBridgeMenuBarApp.swift`
5. הרץ את הפרויקט

## המלצה
אפשר לתת לפרויקט שם כמו:
- TimeBridge
- WorldTimeBar
- TZ Quick Convert

## ברירות מחדל שכבר הכנסתי
- Home: San Antonio / America/Chicago
- Israel: Asia/Jerusalem
- New York: America/New_York
- London: Europe/London

## חשוב לדעת
כרגע זה MVP, כלומר גרסה ראשונה ופשוטה.  
היא עובדת, אבל עדיין אין:
- חיפוש ערים מתקדם עם autocomplete
- ממשק יותר יפה
- תמיכה ב-12h/24h toggle
- העתקה מהירה ללוח
- שמירת preset-ים מתקדמים
- בחירה נוחה דרך מפה

## מה אפשר לשדרג אחר כך
- חישוב דו-כיווני בין כל שתי ערים
- רשימת Favorite presets
- כפתור "Meeting-friendly hours"
- התראה כששעה טובה מתחילה בישראל / אצלך
- תמיכה מלאה בשמות ערים ידידותיים במקום Time Zone IDs
