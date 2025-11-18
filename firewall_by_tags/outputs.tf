# output the curl command to test the web server
output "test_web_server_command" {
  #   value = "curl http://${linode_ip}/"
  value = "curl -v http://${tolist(linode_instance.demo.ipv4)[0]}"
}
