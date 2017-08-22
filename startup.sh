#!/bin/bash
sudo yum -y update
sudo yum -y install perl-Switch perl-DateTime perl-Sys-Syslog perl-LWP-Protocol-https jq
curl http://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.1.zip -O
#rm /var/tmp/aws-mon/instance-id
unzip CloudWatchMonitoringScripts-1.2.1.zip
rm CloudWatchMonitoringScripts-1.2.1.zip
cd aws-scripts-mon
#write out current crontab
crontab -l > mycron
#echo new cron into cron file
echo "*/5 * * * * ~/aws-scripts-mon/mon-put-instance-data.pl --mem-used-incl-cache-buff --mem-util --disk-space-util --disk-path=/ --from-cron" >> mycron
#install new cron file
crontab mycron
rm mycron

EC2_INSTANCE_ID=`curl http://169.254.169.254/latest/meta-data/instance-id`
EC2_AZ=`curl http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION=${EC2_AZ%?}
EC2_ACCOUNTID=`curl http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.accountId'`

aws cloudwatch put-metric-alarm \
 --region=${EC2_REGION} \
 --alarm-name ram-mon-${EC2_INSTANCE_ID} \
 --alarm-description "Alarm when Ram exceeds 70 percent" \
 --metric-name MemoryUtilization \
 --namespace System/Linux \
 --statistic Average \
 --period 300 \
 --threshold 70 \
 --comparison-operator GreaterThanThreshold \
 --dimensions "Name=InstanceId,Value=${EC2_INSTANCE_ID}" \
 --dimensions "Name=AutoScalingGroupName,Value=my-asg" \
 --evaluation-periods 2 \
 --alarm-actions arn:aws:sns:${EC2_REGION}:${EC2_ACCOUNTID}:my-sns-target \
 --unit Percent

aws autoscaling put-scaling-policy \
 --auto-scaling-group-name test-ram-group \
 --policy-name scale-on-ram \
 --policy-type SimpleScaling \
 --scaling-adjustment 1 \
 --adjustment-type ChangeInCapacity \

