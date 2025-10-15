# AWS Vault Setup Guide for Local Development

## Prerequisites
- aws-vault installed on macOS
- AWS account access

## Step 1: Create IAM User in AWS Console

1. Log into [AWS Console](https://console.aws.amazon.com)
2. Navigate to **IAM** → **Users** → **Create User**
3. Enter username (e.g., `adi`)
4. Attach appropriate policies for your needs:
   - `PowerUserAccess` - Recommended for learning (everything except IAM)
   - `AdministratorAccess` - Full access (use carefully)
   - Or specific service policies as needed
5. Click **Next** and **Create User**
6. Go to the user's **Security Credentials** tab
7. Click **Create Access Key**
8. Select **"Command Line Interface (CLI)"** use case
9. Click **Next** and **Create Access Key**
10. **Save both the Access Key ID and Secret Access Key** (download CSV or copy them)

## Step 2: Add Credentials to aws-vault

Open terminal and run:

```bash
aws-vault add adi
```

When prompted, enter:
- **Access Key ID**: (paste from Step 1)
- **Secret Access Key**: (paste from Step 1)

This securely stores your credentials in macOS Keychain.

## Step 3: Configure AWS Profile

Create or edit `~/.aws/config`:

```bash
nano ~/.aws/config
```

Add the following content:

```ini
[profile adi]
region = us-east-1
credential_process = aws-vault export --format=json --no-session adi
```

Save and exit (Ctrl+O, Enter, Ctrl+X in nano).

**Note:** Change `us-east-1` to your preferred AWS region if needed.

## Step 4: Set Default Profile

Edit your shell configuration file:

```bash
nano ~/.zshrc
```

Add this line at the end:

```bash
export AWS_PROFILE=adi
```

Save and exit, then reload your shell:

```bash
source ~/.zshrc
```

## Step 5: Test Your Setup

Run any AWS CLI command:

```bash
aws s3 ls
aws sts get-caller-identity
aws ec2 describe-instances
```

You should now be able to use AWS CLI commands directly without typing `aws-vault exec` each time!

## Verify Setup

Check that aws-vault has your credentials:

```bash
aws-vault list
```

You should see your profile listed.

## Usage

From now on, simply run AWS commands normally:

```bash
aws s3 ls
aws ec2 describe-instances
aws cloudformation list-stacks
```

The AWS CLI will automatically fetch temporary credentials from aws-vault via the `credential_process` configuration.

## How It Works

- Your long-term AWS credentials are stored securely in macOS Keychain
- When you run an AWS command, the CLI calls `aws-vault export`
- aws-vault retrieves your credentials from Keychain and provides them to the CLI
- You never expose your credentials in plain text files
- Each terminal session gets fresh temporary credentials

## Troubleshooting

**If commands don't work:**

1. Verify profile is set:
   ```bash
   echo $AWS_PROFILE
   ```

2. Test aws-vault directly:
   ```bash
   aws-vault exec adi -- aws sts get-caller-identity
   ```

3. Check your config file:
   ```bash
   cat ~/.aws/config
   ```

**If you need to update credentials:**

```bash
aws-vault remove adi
aws-vault add adi
```

Then enter your new Access Key ID and Secret Access Key.