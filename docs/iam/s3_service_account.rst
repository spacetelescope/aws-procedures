Creating and managing an AWS S3 Service Account with minimum permissions
------------------------------------------------------------------------

Security guidelines ask us to create a Role to manage resources, the AWS User Account should be barren, given only
the premission to assume Roles to manage resources. With this approach, roles can be revoked without having to inspect
each User`s permissions

In this document, we'll explore how to create a Role and User to upload files from the `local filesystem`_ to `S3`_.
The Role and User we'll create has enough permissions to write to one bucket in AWS. In the `Python`_ script near the
end, we'll `Assume Role`_ and upload the contents of the local filesystem into AWS S3

.. _`Assume Role`: https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRole.html
.. _`Python`: https://en.wikipedia.org/wiki/Python_(programming_language)
.. _`local filesystem`: https://en.wikipedia.org/wiki/File_system
.. _`S3`: https://aws.amazon.com/s3/`


To begin, navigate to the `IAM Users`_ section of the AWS Console and create a programmatic user by the name of `genericS3Agent`

.. _`IAM Users`: https://console.aws.amazon.com/iam/home?#/users

Create the `genericS3AgentPolicy` to provide the role. Navigate to `IAM Policies`_ in AWS and create `genericS3AgentPolicy`
with the following minimum permissions. There are two Statement entries in the JSON because the first operates on the
items within the bucket, while the second operates on the bucket itself

.. _`IAM Policies`: https://console.aws.amazon.com/iam/home?#/policies


.. code-block:: json

    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:PutObject",
                    "s3:PutObjectAcl"
                ],
                "Resource": "arn:aws:s3:::<bucket-name>/*
            },
            {
                "Effect": "Allow",
                "Action": [
                    "s3:ListObjectsV2",
                    "s3:ListBucket"
                ],
                "Resource": "arn:aws:s3:::<bucket-name>"
            }
        ]
    }



Lets create the `genericS3AgentRole` `here`_ and attach the `genericS3AgentPolicy` created previously to it 

.. _`here`: https://console.aws.amazon.com/iam/home?#/roles


With the `genericS3AgentRole` created, Edit Trust Relationships and remove any trust policies that already exist. Add the following
policy to provide `genericS3Agent` the ability to Assume Role as `genericS3AgentRole` and perform operations on the
bucket defined in `genericS3AgentPolicy` above

.. code-block:: json

    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "AWS": "arn:aws:iam::<aws-account-number>:user/genericS3Agent"
          },
          "Action": "sts:AssumeRole",
          "Condition": {}
        }
      ]
    }


With a minimum permissions and correct Trust Relationship setup, we're ready to test and upload content to our newly
created S3 bucket

To test, we'll assume the creds for `genericS3Agent` has been installed in `~/.aws/credentials` under the alias
`genericS3AgentProfile`. We'll then call the following script from the commandline with the ENVVar `AWS_PROFILE` to tell
`boto3` to use the alias and upload contents from the local filesystem


.. code-block:: python

    #!/usr/bin/env python
    
    import boto3
    import os
    import subprocess
    import sys
    import time
    import typing
    import uuid
    
    client = boto3.client('sts')
    
    SESSION_NAME: str = str(uuid.uuid4())
    ENCODING: str = 'utf-8'
    DURATION: int = 900 # 15 minutes
    try:
        CONTENT_DIR: str = sys.argv[1]
        BUCKET_NAME: str = sys.argv[2]
        ROLE_ARN: str = sys.argv[3]
    except IndexError:
        sys.stderr.write("Invalid usage. Example Usage: \n" 
                "python assume_role.py <local-dir> <bucket-name> <role-arn-to-be-assumed>\n\n")
        sys.exit(1)
    
    
    def run_command(cmd: str, allow_error: typing.List[int] = [0]) -> str:
        cmd: typing.List[str] = cmd.split(' ')
        proc = subprocess.Popen(' '.join(cmd), stdout=sys.stdout, stderr=sys.stderr, shell=True)
        while proc.poll() is None:
            time.sleep(.1)
    
        if proc.poll() > 0:
            if not proc.poll() in allow_error:
                sys.exit(1)
    
    response = client.assume_role(RoleArn=ROLE_ARN, RoleSessionName=SESSION_NAME, DurationSeconds=DURATION)
    os.environ['AWS_ACCESS_KEY_ID'] = response['Credentials']['AccessKeyId']
    os.environ['AWS_SECRET_ACCESS_KEY'] = response['Credentials']['SecretAccessKey']
    os.environ['AWS_SESSION_TOKEN'] = response['Credentials']['SessionToken']
    run_command('cd %s && aws s3 sync . s3://%s ' % (CONTENT_DIR, BUCKET_NAME))


.. code-block:: bash

    $ mkdir -p /tmp/test-s3
    $ touch /tmp/test-s3/one
    $ touch /tmp/test-s3/two
    $ cd /tmp/test-s3
    $ AWS_PROFILE=genericS3AgentProfile python assume_role.py ./ <bucket-name>/<sub-directory> arn:aws:iam::<aws-account-number>:role/genericS3AgentRole

