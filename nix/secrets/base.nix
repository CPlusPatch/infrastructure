{
  # Set by the Terraform deployment
  sops = {
    # If Sops is asking for this, it means that you misspelled or forgot to import
    # one of the secrets configurations
    # defaultSopsFile = ../../secrets/docker.yaml;
    age.keyFile = "/var/lib/secrets/age";
  };
}
