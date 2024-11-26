Here is a sample README file for your script:  

---

# Vault HA Cluster Automation Script  

### **Description**  
This script automates the deployment and setup of a Vault High Availability (HA) cluster using the Raft integrated storage backend. It simplifies the initialization, unsealing, and configuration of Vault in a Kubernetes environment.  

---

### **Features**  
- Deploys Vault in HA mode with multiple replicas.  
- Initializes the Vault cluster and unseals the primary node.  
- Joins secondary nodes to the Raft cluster.  
- Verifies the cluster status.  

---

### **Prerequisites**  
1. A Kubernetes cluster with Helm installed.  
2. Vault Helm chart installed and configured.  
3. Kubectl access to the cluster.  
4. Sufficient permissions to manage Vault resources.  

---

### **Usage**  

1. **Clone the Repository**  
   ```bash  
   git clone <repository-url>  
   cd <repository-directory>  
   ```  

2. **Edit Configuration**  
   Ensure the `values.yaml` file for the Vault Helm chart is correctly configured for HA mode with Raft.  

3. **Run the Script**  
   ```bash  
   ./vault-ha-setup.sh  
   ```  

4. **Verify Cluster Status**  
   After running the script, check the status of the Vault cluster:  
   ```bash  
   vault operator raft list-peers  
   ```  

---

### **File Structure**  
- `vault-ha-setup.sh`: The main script for automating the Vault HA cluster setup.  

---

### **Author**  
Daniel Mandelblat  

---

### **Last Updated**  
November 26, 2024  

---

If you'd like any additional sections or edits, let me know!
