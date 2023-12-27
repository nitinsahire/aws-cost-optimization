import boto3
from tabulate import tabulate

def lambda_handler(event, context):
    regions = ['us-east-1']
    unused_vols = []
    volume_info_list = []

    for region in regions:
        ec2_client = boto3.client('ec2', region_name=region)
        volumes = ec2_client.describe_volumes()

        for volume in volumes['Volumes']:
            if len(volume['Attachments']) == 0:
                unused_vols.append(volume['VolumeId'])
                volume_info = (
                    volume['CreateTime'].strftime('%Y-%m-%d %H:%M:%S'),
                    volume['VolumeId'],
                    volume['Size'],
                    volume['State'],
                    volume['VolumeType'],
                    volume['Tags'][0]['Value'] if 'Tags' in volume and volume['Tags'] else '',  # Environment tag
                    volume['AvailabilityZone'],
                    volume['Tags'][1]['Value'] if 'Tags' in volume and len(volume['Tags']) > 1 else ''  # Name tag
                )
                volume_info_list.append(volume_info)

    table_headers = [
        'Created Time',
        'VolumeId',
        'Size',
        'State',
        'VolumeType',
        'Environment',
        'AvailabilityZone',
        'Name']
    table = tabulate(volume_info_list, headers=table_headers, tablefmt='grid')
    print(table)

    # Here you can send the output to SNS, email, or other desired destinations.
    # For simplicity, we are just printing the table to the CloudWatch Logs.
