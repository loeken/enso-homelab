package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

const terraformDir = "../../terraform/k3s"
const sshKeyPath = "~/.ssh/id_ed25519"

func main() {
	if len(os.Args) != 4 {
		fmt.Println("Usage: ./ensoctl <ssh_username> <ssh_server_address> <hostname>")
		os.Exit(1)
	}

	sshUsername := os.Args[1]
	sshServerAddress := os.Args[2]
	expectedHostname := os.Args[3]

	if err := verifyHostname(sshUsername, sshServerAddress, expectedHostname); err != nil {
		fmt.Printf("Hostname verification failed: %v\n", err)
		os.Exit(1)
	}

	externalIP, err := getExternalIP()
	if err != nil {
		fmt.Printf("Failed to retrieve external IP: %v\n", err)
		os.Exit(1)
	}

	if err := terraformInit(); err != nil {
		fmt.Printf("Terraform init failed: %v\n", err)
		os.Exit(1)
	}

	planOutput, err := terraformPlan(sshUsername, sshServerAddress, externalIP)
	if err != nil {
		fmt.Printf("Terraform plan failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Println(planOutput)

	if hasNoChanges(planOutput) {
		fmt.Println("No changes to apply.")
		return
	}

	if err := terraformApply(sshUsername, sshServerAddress, externalIP); err != nil {
		fmt.Printf("Terraform apply failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("Terraform apply executed successfully.")
}

func verifyHostname(username, serverAddress, expectedHostname string) error {
	cmd := exec.Command("ssh", "-i", sshKeyPath, fmt.Sprintf("%s@%s", username, serverAddress), "hostname")
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("SSH command failed: %v, stderr: %s", err, stderr.String())
	}

	actualHostname := strings.TrimSpace(stdout.String())
	if actualHostname != expectedHostname {
		return fmt.Errorf("expected hostname '%s', got '%s'", expectedHostname, actualHostname)
	}

	return nil
}

func terraformInit() error {
	cmd := exec.Command("terraform", "init", "-input=false")
	cmd.Dir = terraformDir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func terraformPlan(username, serverAddress, externalIP string) (string, error) {
	var stdout, stderr bytes.Buffer
	cmd := exec.Command("terraform", "plan", "-input=false",
		"-var", fmt.Sprintf("ssh_username=%s", username),
		"-var", fmt.Sprintf("ssh_server_address=%s", serverAddress),
		"-var", fmt.Sprintf("external_ip=%s", externalIP),
	)
	cmd.Dir = terraformDir
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		return stderr.String(), err
	}

	return stdout.String(), nil
}

func terraformApply(username, serverAddress, externalIP string) error {
	cmd := exec.Command("terraform", "apply", "-auto-approve", "-input=false",
		"-var", fmt.Sprintf("ssh_username=%s", username),
		"-var", fmt.Sprintf("ssh_server_address=%s", serverAddress),
		"-var", fmt.Sprintf("external_ip=%s", externalIP),
	)
	cmd.Dir = terraformDir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func hasNoChanges(output string) bool {
	return strings.Contains(output, "No changes. Your infrastructure matches the configuration.")
}

func getExternalIP() (string, error) {
	var stdout, stderr bytes.Buffer
	cmd := exec.Command("curl", "-s", "ifconfig.co", "-4")
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		return "", err
	}

	return strings.TrimSpace(stdout.String()), nil
}