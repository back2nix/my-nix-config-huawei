# Handover: Windows Jupyter зависимости — soft_collect_model PROD

**Дата:** 2026-05-14  
**Машина:** `ssh bagau` (Windows)  
**Ноутбук:** `C:\Users\bagau\code\Devim\jupyter\models\soft_collect_model\PROD\Новая папка\model.ipynb`

> ⚠️ **Исправление:** `.venv` нужно создавать в `C:\Users\bagau\code\Devim\jupyter\.venv\`, а не в `PROD\.venv\`.

---

## Что было сделано

### 1. Включена поддержка длинных путей Windows
```
reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t REG_DWORD /d 1 /f
```
Без этого `pip install ipywidgets` падал с OSError — путь к файлу jupyterlab-manager превышал 260 символов.

### 2. Установлены зависимости в .venv (Python 3.12)

Путь к окружению:
```
C:\Users\bagau\code\Devim\jupyter\.venv\
```

> ⚠️ Предыдущая установка была ошибочно сделана в `PROD\.venv\` — правильное место `jupyter\.venv\`.

Python в окружении: **3.12.8**

Установлено (итоговые версии):
| Пакет | Версия |
|---|---|
| clickhouse-connect | 0.15.1 |
| python-dotenv | 1.2.2 |
| joblib | 1.5.3 |
| pandas | 2.3.3 |
| numpy | 1.26.4 |
| seaborn | 0.13.2 |
| matplotlib | 3.10.9 |
| pyodbc | 5.3.0 |
| psycopg2-binary | 2.9.12 |
| sqlalchemy | 2.0.49 |
| lightgbm | 4.6.0 |
| optuna | 4.8.0 |
| optbinning | 0.21.0 |
| shap | 0.45.1 |
| scikit-learn | 1.8.0 |
| mlflow | **2.14.1** (фиксировано, не менять) |
| ipykernel | 7.2.0 |
| ipywidgets | 8.1.8 |
| boto3 | 1.43.7 |
| botocore | 1.43.7 |
| s3transfer | 0.17.0 |
| jmespath | 1.1.0 |
| scorecardpy | 0.1.9.7 |
| statsmodels | 0.14.6 |
| patsy | 1.0.2 |

### 3. Установлен boto3 (14.05.2026)

`mlflow.lightgbm.log_model` и `mlflow.log_artifact` требуют `boto3` даже при локальном artifact store — модуль импортируется при загрузке. Установлено через `pip3.exe`:

```bash
ssh bagau 'C:\Users\bagau\code\Devim\jupyter\.venv\Scripts\pip3.exe install boto3'
```

Результат: `boto3-1.43.7`, `botocore-1.43.7`, `s3transfer-0.17.0`, `jmespath-1.1.0`.

---

### 4. Разрешение конфликта зависимостей

`mlflow==2.14.1` требует `numpy<2` и `protobuf<5`. Это конфликтует с последними версиями `shap` (>=0.46 требует numpy>=2) и `ortools`. Решение:

- `numpy` понижен до `1.26.4`
- `shap` понижен до `0.45.1` (последняя совместимая с numpy 1.x)
- `cvxpy` понижен до `1.5.4`
- `ortools` понижен до `9.8.3296` (совместим с protobuf 4.x)
- `protobuf` зафиксирован на `4.25.9`
- `setuptools` понижен до `71.1.0` (версии >=72 убрали `pkg_resources`, который нужен mlflow 2.14.1)

### 4. Зарегистрирован Jupyter kernel

```
C:\Users\bagau\AppData\Roaming\jupyter\kernels\soft_collect_prod\kernel.json
```

Kernel запускает Python из `.venv` напрямую:
```json
{
  "argv": [
    "C:\\Users\\bagau\\code\\Devim\\jupyter\\.venv\\Scripts\\python.exe",
    "-Xfrozen_modules=off",
    "-m", "ipykernel_launcher",
    "-f", "{connection_file}"
  ],
  "display_name": "Python (jupyter)",
  "language": "python"
}
```

---

## Как использовать в VSCode

1. Открыть ноутбук в VSCode
2. Нажать на кнопку выбора ядра (правый верхний угол)
3. **Select Another Kernel... → Jupyter Kernel... → `Python (jupyter)`**
4. Если kernel не виден — `Ctrl+Shift+P` → `Developer: Reload Window`

---

## Важные замечания

- **Python 3.11 (Microsoft Store)** — основной Python пользователя, там Jupyter. В нём уже были установлены большинство пакетов, но версии отличались. Через SSH Microsoft Store Python **не запускается** (ограничение системы).
- **mlflow==2.14.1** — зафиксирован. Обновление потребует пересмотра всей цепочки зависимостей (numpy, protobuf, shap, cvxpy, ortools).
- В Python 3.11 есть конфликт: установлены `mlflow-2.14.1` и `mlflow_skinny-3.12.0` одновременно. При необходимости очистить: удалить `mlflow_skinny` и `mlflow_tracing` из site-packages Python 3.11.

---

## Проверка работоспособности

```bash
ssh bagau
"C:\Users\bagau\code\Devim\jupyter\.venv\Scripts\python.exe" -c "
import clickhouse_connect, dotenv, joblib, pandas, numpy, seaborn, matplotlib
import pyodbc, psycopg2, sqlalchemy, lightgbm, optuna, optbinning, shap, sklearn
import mlflow
print('mlflow:', mlflow.__version__)
print('numpy:', numpy.__version__)
print('ALL OK')
"
```

Ожидаемый вывод:
```
mlflow: 2.14.1
numpy: 1.26.4
ALL OK
```
