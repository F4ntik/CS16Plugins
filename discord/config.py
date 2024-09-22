#-------------------------------------------------------------------
#-- Asura Bot Version
#-------------------------------------------------------------------
_VERSION_ = 0.2

#-------------------------------------------------------------------

# Токен бота для доступа к API Discord
BOT_TOKEN = ''

# Ключ API для доступа к сторонним сервисам (если требуется)
API_KEY = ''

# Идентификатор гильдии (сервера) Discord, на котором работает бот
GUILD_ID = 

# Идентификатор канала, в который бот будет отправлять сообщения из чата
CS_CHAT_CHNL_ID = 

# Идентификатор канала для администраторов
ADMIN_CHANNEL_ID = 

# Идентификатор информационного канала
INFO_CHANNEL_ID = 

# Интервал обновления статуса бота в секундах
STATUS_INTERVAL = 10

# Хост и пароль для подключения к серверу (например, игровому серверу)
CS_HOST = '127.0.0.1'  # Локальный хост
CS_RCON_PASSWORD = '12345'  # Пароль для удаленного управления

# Настройки подключения к базе данных
DB_HOST = '127.0.0.1'  # Хост базы данных
#DB_PORT = 3306  # Порт базы данных
DB_USER = 'root'  # Имя пользователя базы данных
DB_PASSWORD = ''  # Пароль пользователя базы данных
DB_NAME = 'create_test'  # Имя базы данных


# Порт веб-сервера, на котором будет работать приложение
WEB_HOST_ADDRESS = '0.0.0.0'
WEB_SERVER_PORT = 8080

# redis (универсальные значения)
REDIS_HOST = '127.0.0.1'
REDIS_PORT = 6379