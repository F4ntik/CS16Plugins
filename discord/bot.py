import asyncio
import logging
from datetime import datetime  # Для добавления timestamp

import discord
from aiohttp import web
from discord.ext import commands, tasks
import mysql.connector
from mysql.connector import errorcode

import config
from rehlds.console import Console

# Настройка логирования
logging.basicConfig(level=logging.INFO)

srv = Console(host=config.CS_HOST, password=config.CS_RCON_PASSWORD)

app = web.Application()

intents = discord.Intents.default()
intents.message_content = True
intents.members = True

bot = commands.Bot(command_prefix='/', intents=intents)

auto_reconnect_lock = asyncio.Lock()


# Запуск веб-сервера
async def run_webserver():
    try:
        runner = web.AppRunner(app)
        await runner.setup()
        site = web.TCPSite(runner, config.WEB_HOST_ADDRESS, config.WEB_SERVER_PORT)
        await site.start()
        logging.info(f"WebServer запущен на {config.WEB_HOST_ADDRESS}:{config.WEB_SERVER_PORT}")
    except Exception as e:
        logging.error(f"Не удалось запустить WebServer: {e}")


# Подключение к серверу CS
async def connect_to_cs():
    try:
        srv.connect()
        logging.info("Успешно подключено к CS Server")
    except Exception as e:
        logging.error(f"Ошибка при соединении с CS Server: {e}")
        raise


# Периодическое задание для обновления статуса
@tasks.loop(seconds=config.STATUS_INTERVAL)  # Задача будет выполняться каждые 10 секунд
async def status_task():
    if not srv.is_connected:
        return
    try:
        srv.execute("ultrahc_ds_get_info")
    except Exception as e:
        logging.error(f"Ошибка при подключении к CS Server: {e}")
        if not auto_reconnect_lock.locked():
            asyncio.create_task(auto_reconnect())


async def auto_reconnect():
    admin_channel = bot.get_channel(config.ADMIN_CHANNEL_ID)
    if admin_channel is None:
        logging.warning(
            "Не удалось получить канал администратора для уведомлений о переподключении"
        )

    async with auto_reconnect_lock:
        max_attempts = 3
        for attempt in range(1, max_attempts + 1):
            try:
                await connect_to_cs()
            except Exception as e:
                logging.error(
                    f"Автоматическая попытка #{attempt} подключения к CS Server завершилась ошибкой: {e}"
                )
                if attempt < max_attempts:
                    await asyncio.sleep(10 * attempt)
                else:
                    if admin_channel is not None:
                        await admin_channel.send(
                            "Что соеденение с сервером cs пропало, пробуем переподключится..."
                        )
                        await admin_channel.send(
                            "Автоматическое восстановление соединения не удалось. "
                            "Пожалуйста, вызовите команду /connect_to_cs для ручного подключения."
                        )
            else:
                if admin_channel is not None:
                    await admin_channel.send(
                        "Соединение с сервером CS успешно восстановлено автоматически."
                    )
                return


@status_task.before_loop
async def before_status_task():
    await bot.wait_until_ready()
