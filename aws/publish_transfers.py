"""Publish simulated CPO custody-transfer events to Amazon Data Firehose (stream <prefix>-transfers).

Firehose batches the records into S3 (transfers/); Snowpipe loads them into RAW.LIVE_TRANSFERS.
Mill IDs come from RAW.MILLS (MILL-0000..MILL-0039). Values are seeded random.
"""
import argparse
import json
import random
import time
from datetime import datetime, timezone


def make_event(rng):
    flag = rng.random() < 0.1
    return {'mill_id': f'MILL-{rng.randint(0, 39):04d}',
            'event_ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3],
            'transfer_tonnes': round((22 if flag else 28) * rng.lognormvariate(0, 0.12), 2),
            'mb_variance_pct': round(max(0.0, rng.gauss(7.5 if flag else 1.2, 0.8)), 2),
            'status': 'FLAG' if flag else 'OK',
            'sent_ms': int(time.time() * 1000)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', default='us-west-2')
    ap.add_argument('--prefix', default='id-palm-oil-traceability')
    ap.add_argument('--count', type=int, default=40)
    ap.add_argument('--seed', type=int)
    args = ap.parse_args()
    import boto3
    firehose = boto3.client('firehose', region_name=args.region)
    stream = f'{args.prefix}-transfers'
    rng = random.Random(args.seed)
    records = [{'Data': (json.dumps(make_event(rng)) + '\n').encode()} for _ in range(args.count)]
    for start in range(0, len(records), 500):
        out = firehose.put_record_batch(DeliveryStreamName=stream, Records=records[start:start + 500])
        if out['FailedPutCount']:
            raise RuntimeError(f"{out['FailedPutCount']} records were rejected by Firehose")
    print(f'published {args.count} custody-transfer events to Firehose stream {stream}; S3 delivery buffers up to 60 s')


if __name__ == '__main__':
    main()
