#!/usr/bin/python3

# Run background
# nohup ./client-logs.py &> /dev/null &

# Autorun
# crontab -e
# @reboot ~/client-logs.py

import socket
import subprocess
import time
import json
import select
import os
import signal

def tail_logs(container_name, reconect_time = None):
    while True:
        while True:

            if reconect_time is not None:
                process = subprocess.run(['docker', 'logs', '-t', '--since', reconect_time, container_name], stdout=subprocess.PIPE, stderr=subprocess.PIPE, preexec_fn=os.setsid)
                result = process.stderr.decode('utf-8') + process.stdout.decode('utf-8')
                os.killpg(os.getpgid(process.pid), signal.SIGKILL)
                reconect_time = None
                yield result
                break

            process = subprocess.Popen(['docker', 'logs', '--tail', '0', '-t', '-f', container_name], stdout=subprocess.PIPE, stderr=subprocess.PIPE, preexec_fn=os.setsid)

            ready, _, _ = select.select([process.stdout, process.stderr], [], [], 300)
            if not ready:
                os.killpg(os.getpgid(process.pid), signal.SIGKILL)
                print('Since')
                process = subprocess.run(['docker', 'logs', '-t', '--since', '299s', container_name], stdout=subprocess.PIPE, stderr=subprocess.PIPE, preexec_fn=os.setsid)
                result = process.stderr.decode('utf-8') + process.stdout.decode('utf-8')
                os.killpg(os.getpgid(process.pid), signal.SIGKILL)
                yield result
                break

            result = ""

            if process.stdout in ready:
                result += process.stdout.readline().decode('utf-8')

            if process.stderr in ready:
                result += process.stderr.readline().decode('utf-8')

            os.killpg(os.getpgid(process.pid), signal.SIGKILL)
            yield result

def main(container_name, db_name, host, port, reconect_time):

    _reconect_time = reconect_time

    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        try:
            sock.connect((host, port))
            sock.sendall(bytes(json.dumps({"type": "auth", "name": db_name}) + "\n", encoding="utf-8"))
            print("Connected.")

            for data in tail_logs(container_name, reconect_time):

                if not data: continue

                obj = []

                for line in data.split('\n'):
                    if line == '': break

                    time_end_index = line.index(' ')
                    timeLog = line[:time_end_index]
                    log = line[time_end_index+1:]

                    obj.append({"time": timeLog, "log": log})

                if len(obj) > 0:
                    obj = sorted(obj, key=lambda x: x['time'])
                    sock.sendall(bytes(json.dumps({"type": "add", "data": obj}) + "\n", encoding="utf-8"))
                    _reconect_time = obj[0]["time"]

        except socket.error as e:
            print(f"Socket error: {e}")

        except Exception as e:
            print(f"Error: {e}")

        finally:
            sock.close()

    print("Disconnected.")

    time.sleep(3)

    print("Reconnecting...")

    return main(container_name, db_name, host, port, _reconect_time)

if __name__ == "__main__":
    container_name = "streamlive-kick-32307"
    db_name = "Test"
    host = "127.0.0.1"
    port = 34092

    main(container_name, db_name, host, port, None)
