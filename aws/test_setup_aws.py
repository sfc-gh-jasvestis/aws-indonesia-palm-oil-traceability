import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from publish_transfers import make_event
from setup_aws import firehose_request, ident, names


class SetupAwsTests(unittest.TestCase):
    def test_names_are_scoped_to_prefix_account_region(self):
        n = names('id-palm-oil-traceability', '123456789012', 'us-west-2')
        self.assertEqual(n['bucket'], 'id-palm-oil-traceability-123456789012-us-west-2')
        self.assertEqual(n['storage_int'], 'ID_PALM_OIL_TRACEABILITY_S3_INT')
        self.assertEqual(n['firehose_stream'], 'id-palm-oil-traceability-transfers')

    def test_rejects_unsafe_identifiers(self):
        for bad in ['DB; DROP', 'a-b', '1abc', '']:
            with self.assertRaises(ValueError):
                ident(bad)

    def test_firehose_request_matches_aws_schema(self):
        import botocore.session
        from botocore.validate import validate_parameters
        n = names('id-palm-oil-traceability', '123456789012', 'us-west-2')
        req = firehose_request(n, n['bucket'], 'arn:aws:iam::123456789012:role/id-palm-oil-traceability-firehose-s3')
        model = botocore.session.get_session().get_service_model('firehose')
        validate_parameters(req, model.operation_model('CreateDeliveryStream').input_shape)
        dest = req['ExtendedS3DestinationConfiguration']
        self.assertEqual(dest['Prefix'], 'transfers/')
        self.assertFalse(dest['ErrorOutputPrefix'].startswith('transfers/'))

    def test_transfer_event_matches_pipe_columns(self):
        import random
        event = make_event(random.Random(7))
        self.assertEqual(set(event), {'mill_id', 'event_ts', 'transfer_tonnes', 'mb_variance_pct', 'status', 'sent_ms'})
        self.assertRegex(event['mill_id'], r'^MILL-00[0-3]\d$')
        self.assertIn(event['status'], ('FLAG', 'OK'))


if __name__ == '__main__':
    unittest.main()
