#!/bin/bash

# Функция для выполнения curl-запроса
make_request() {
    local request_number=$1  # Номер запроса
    local request_url=$2     # URL для запроса
    local error_file=$3      # Файл для записи ошибок
    local timeout=$4         # Таймаут для запроса в секундах

    # Выполняем curl с таймаутом
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $timeout "$request_url")

    # Проверяем, если код ответа не 200, записываем ошибку в файл
    if [ "$response" -eq 503 ]; then
        echo "Request #$request_number failed with HTTP code $response" >> "$error_file"
    fi
}

# Параметры для тестирования
error_log="error_log.txt"  # Файл для записи ошибок
url="http://127.0.0.1:80/calc?input=SGVsbG9Xb3JsZA=="  # Строка запроса
timeout=4  # Таймаут в секундах

# Очищаем файл с ошибками перед запуском
> "$error_log"

# Запускаем несколько запросов
for i in {1..300}; do
    make_request $i "$url" "$error_log" "$timeout" &
done

# Ожидаем завершения всех фоновых процессов
wait

echo "Тестирование завершено. Проверьте файл $error_log на наличие ошибок."
