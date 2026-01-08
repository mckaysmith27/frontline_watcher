# EC2 Instance Creation Guide - Exact Settings

## Step-by-Step Instructions

### Step 1: Go to EC2 Console
1. Go to [AWS EC2 Console](https://console.aws.amazon.com/ec2/)
2. Make sure you're in the correct region (e.g., `us-east-2` based on your previous instance)
3. Click **"Launch Instance"** button

### Step 2: Name and Tags
- **Name**: `frontline-watcher-new` (or any name you prefer)

### Step 3: Application and OS Images (AMI)
- **Quick Start**: Select **"Ubuntu"**
- **Version**: **Ubuntu Server 22.04 LTS** (or latest 22.04)
- **Architecture**: **64-bit (x86)**

### Step 4: Instance Type
- **Instance type**: **t3.micro** (or **t3.small** if you want more resources)
  - t3.micro: 2 vCPU, 1 GB RAM (~$7-8/month)
  - t3.small: 2 vCPU, 2 GB RAM (~$15/month)
- **Recommendation**: Start with **t3.micro** (can upgrade later if needed)

### Step 5: Key Pair (Login)
- **Key pair name**: Select **"frontline-watcher_V6plus-key"** (your existing key)
- **Key pair type**: RSA
- **Private key file format**: `.pem` (default)
- ⚠️ **Important**: If you don't see your key, you may need to create a new one or use an existing one

### Step 6: Network Settings
- **VPC**: Use default VPC (or your existing VPC)
- **Subnet**: Use default subnet (or your existing subnet)
- **Auto-assign Public IP**: **Enable**
- **Security Group**: 
  - **Create new security group** (or use existing)
  - **Name**: `frontline-watcher-sg`
  - **Description**: `Frontline Watcher Scraper`
  - **Inbound rules**: 
    - **Type**: SSH
    - **Protocol**: TCP
    - **Port**: 22
    - **Source**: **My IP** (or `0.0.0.0/0` if you want to allow from anywhere - less secure)

### Step 7: Configure Storage
- **Volume 1 (Root)**: 
  - **Size (GiB)**: **30**
  - **Volume type**: **gp3** (General Purpose SSD)
  - **Delete on termination**: ✅ **Checked** (so storage is deleted when instance is terminated)
  - **Encrypted**: Optional (can leave unchecked for now)

### Step 8: Advanced Details (Optional)
- **User data**: Leave blank (we'll set up via SSH)
- **IAM role**: None (unless you need specific permissions)
- **Shutdown behavior**: Stop (default)
- **Termination protection**: Unchecked (can enable later if needed)

### Step 9: Summary and Launch
1. Review all settings
2. Click **"Launch Instance"**
3. Wait for status to show **"Running"** (usually 1-2 minutes)

### Step 10: Get Public IP
1. Click on your instance name
2. In the **"Instance summary"** panel, find **"Public IPv4 address"**
3. **Copy this IP** - you'll need it for SSH

## Quick Reference - All Settings

| Setting | Value |
|---------|-------|
| **Name** | `frontline-watcher-new` |
| **AMI** | Ubuntu Server 22.04 LTS |
| **Instance Type** | t3.micro (or t3.small) |
| **Key Pair** | `frontline-watcher_V6plus-key` |
| **Storage** | 30 GB gp3 |
| **Security Group** | SSH (port 22) from My IP |
| **Public IP** | Enable auto-assign |

## After Instance is Running

1. **Note the Public IP** from instance details
2. **Test SSH connection**:
   ```bash
   ssh -i ~/.ssh/frontline-watcher_V6plus-key ubuntu@<PUBLIC_IP>
   ```
3. **If SSH works**, proceed with setup:
   ```bash
   cd ~/Sub67/frontline_watcher
   ./ec2/interactive-setup.sh
   ```

## Troubleshooting

### Can't Find Key Pair
- If your key pair isn't listed, you may need to:
  1. Create a new key pair in EC2 Console
  2. Download the `.pem` file
  3. Save to `~/.ssh/` with proper permissions: `chmod 400 ~/.ssh/your-key.pem`

### SSH Connection Refused
- Wait 1-2 minutes after instance starts (SSH service needs time to start)
- Check Security Group allows SSH from your IP
- Verify you're using the correct key file

### Wrong Region
- Make sure you're in the same region as your previous instance (likely `us-east-2`)
- Check the region selector in top-right of EC2 Console

## Cost Estimate

- **t3.micro**: ~$7-8/month (~$0.0104/hour)
- **t3.small**: ~$15/month (~$0.0208/hour)
- **Storage (30 GB gp3)**: ~$2.40/month
- **Total (t3.micro)**: ~$10/month

## Next Steps After Creation

Once instance is running:
1. Get Public IP
2. Run: `./ec2/interactive-setup.sh`
3. When prompted, enter: `ubuntu@<PUBLIC_IP>`
4. Answer: `1` for number of controllers (only controller_1)
