'use client';

import { useEffect, useState } from 'react';
import { AppLayout } from '@/components/AppLayout';
import { KPICard } from '@/components/KPICard';
import { Chart } from '@/components/Chart';
import { DataTable } from '@/components/DataTable';
import { AskAI } from '@/components/AskAI';
import { ActionMemo } from '@/components/ActionMemo';

interface TraceData {
  platform: 'snowflake' | 'aws';
  kpiCards: { title: string; value: string }[];
  timeseries: { period: string; dispatches: number | null; flags: number | null }[];
  categories: { category: string; flags: number | null; confirmed: number | null }[];
  entities: Record<string, string | number | null>[];
  reconciliationRisk: { name: string; compliance: number; confirmed: number }[];
  sourceWatermark: string | null;
  rawWatermark: string | null;
  requestedAt: string;
  stale: boolean;
  pipelineBehind: boolean;
  risk: Record<string, string | number | null>[];
  holdout: { n: number | null; baseRate: number | null; precision: number | null; recall: number | null } | null;
  forecast: { period: string; value: number | null; lower: number | null; upper: number | null }[];
  live: Record<string, string | number | null>[];
  liveSummary: { n: number | null; flags: number | null; lastLoaded: string | null; medianLagSeconds: number | null };
  anomalies: Record<string, string | number | null>[];
  alerts: Record<string, string | number | null>[];
}

const pct = (value: number | null) => (value === null ? 'n/a' : `${(value * 100).toFixed(0)}%`);

export default function HomePage() {
  const [data, setData] = useState<TraceData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);
    setData(null);
    fetch('/api/data', { cache: 'no-store', signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error('Data request failed');
        const payload = await response.json();
        if (!Array.isArray(payload.kpiCards) || !Array.isArray(payload.entities)) throw new Error('Invalid contract');
        return payload;
      })
      .then(setData)
      .catch(() => {
        if (!controller.signal.aborted) setError('Snowflake data is unavailable. No fallback values are displayed.');
      })
      .finally(() => { if (!controller.signal.aborted) setLoading(false); });
    return () => controller.abort();
  }, [attempt]);

  const isAws = (data?.platform ?? 'aws') === 'aws';
  const awsDiagram = { key: 'aws', title: 'AWS + Snowflake', src: '/architecture-aws.html' };
  const sfDiagram = { key: 'snowflake', title: 'Snowflake Only', src: '/architecture-snowflake.html' };
  const diagrams = isAws ? [awsDiagram, sfDiagram] : [sfDiagram, awsDiagram];
  const kpiVal = (title: string) => data?.kpiCards.find((card) => card.title === title)?.value ?? 'Unavailable';
  const executive = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {['Traceability to Plantation', 'CPO Custody Transfers', 'CPO Dispatched (kt)', 'Flag Precision'].map((title) => (
          <KPICard key={title} title={title} value={kpiVal(title)} status="neutral" />
        ))}
      </div>
      <p className="text-sm text-slate-600">Traceability to plantation = CPO tonnes traceable to a plantation / CPO tonnes dispatched. Flag precision = confirmed custody breaks / custody flags. Volumes are tonnes of crude palm oil (CPO). Custody checks are demo signals, not audit or certification verdicts.</p>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Chart data={data?.timeseries ?? []} type="line" xKey="period"
          yKeys={[{ key: 'dispatches', name: 'CPO custody transfers' }, { key: 'flags', name: 'Custody flags' }]} title="Daily CPO Custody Transfers and Custody Flags" />
        <Chart data={data?.categories ?? []} type="bar" xKey="category"
          yKeys={[{ key: 'flags', name: 'Flags' }, { key: 'confirmed', name: 'Confirmed custody breaks' }]} title="Custody Flags and Confirmed Custody Breaks by Custody Signal" />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Mill' }, { key: 'region', header: 'City' }, { key: 'category', header: 'Sourcing model' },
        { key: 'dispatches', header: 'Transfers' }, { key: 'traceability', header: 'Traced to plantation (%)' }, { key: 'tracedKt', header: 'Traced (kt)' },
        { key: 'flags', header: 'Flags' }, { key: 'confirmed', header: 'Confirmed' }, { key: 'precision', header: 'Precision (%)' },
      ]} data={data?.entities ?? []} title="Mill observations" />
    </div>
  );
  const predictive = (
    <div className="space-y-4">
      <h2 className="font-semibold">7-day custody-break risk and CPO dispatch forecast</h2>
      <p className="text-sm text-slate-600">
        Snowflake ML classification predicts the probability that a mill has a confirmed custody break in the next 7 days,
        from mass-balance variance, the share of CPO tonnes not traced to a plantation, recent confirmed breaks, days since the last mass-balance reconciliation, the 30-day reconciliation return rate, risk tier, years in the traceability programme and sourcing model.
      </p>
      {data?.holdout ? (
        <p role="status" className="text-sm text-slate-700">
          Out-of-time holdout ({data.holdout.n} mill-days): precision {pct(data.holdout.precision)} and recall{' '}
          {pct(data.holdout.recall)} at a 0.5 threshold, versus a {pct(data.holdout.baseRate)} base rate.
        </p>
      ) : (
        <p role="status">Model outputs are not deployed. Run snowflake/05_ml.sql.</p>
      )}
      <DataTable columns={[
        { key: 'id', header: 'Mill' }, { key: 'band', header: 'Risk band' },
        { key: 'probability', header: 'P(custody break in 7 days)' }, { key: 'scoredAsOf', header: 'Scored as of' },
      ]} data={data?.risk ?? []} title="Custody-break risk by mill" />
      <Chart data={data?.forecast ?? []} type="line" xKey="period"
        yKeys={[{ key: 'value', name: 'Forecast' }, { key: 'lower', name: 'Lower' }, { key: 'upper', name: 'Upper' }]}
        title="Network-wide CPO dispatch forecast, next 14 days (custody transfers per day)" />
      <DataTable columns={[
        { key: 'id', header: 'Mill' }, { key: 'date', header: 'Date' }, { key: 'variance', header: 'Mass-balance variance (%)' },
        { key: 'expected', header: 'Expected' }, { key: 'upper', header: 'Upper bound' },
      ]} data={data?.anomalies ?? []} title="Mass-balance variance anomalies, last 15 days (Snowflake ML anomaly detection, trained on the prior 75 days)" />
    </div>
  );
  const liveTab = (
    <div className="space-y-4">
      <h2 className="font-semibold">{isAws ? 'Live dispatches: S3 upload to Snowpipe' : 'Live dispatches: Snowflake-native simulator'}</h2>
      <p className="text-sm text-slate-600">
        {isAws
          ? 'Simulated CPO custody-transfer events are sent to Amazon Data Firehose (aws/publish_transfers.py), which writes them to the S3 landing bucket under transfers/, and Snowpipe auto-ingest loads them into RAW.LIVE_TRANSFERS.'
          : 'CALL APP.SIMULATE_TRANSFERS(n) inserts simulated CPO custody-transfer events directly into RAW.LIVE_TRANSFERS (or resume APP.TASK_SIMULATE_TRANSFERS for a feed every minute). This simulates a mill dispatch feed; it is not Snowpipe Streaming.'}
        {' '}A FLAG event is a transfer whose mass-balance variance is out of tolerance. The alert APP.LIVE_TRANSFER_ALERT logs FLAG events and emails the traceability team.
      </p>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPICard title="Transfer events loaded" value={String(data?.liveSummary?.n ?? 'n/a')} />
        <KPICard title="FLAG events" value={String(data?.liveSummary?.flags ?? 'n/a')} />
        <KPICard title={isAws ? 'Median send to table lag (s)' : 'Median generated to table lag (s)'} value={String(data?.liveSummary?.medianLagSeconds ?? 'n/a')} />
        <KPICard title="Last load" value={data?.liveSummary?.lastLoaded ?? 'none'} />
      </div>
      <DataTable columns={[
        { key: 'id', header: 'Mill' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'tonnes', header: 'CPO (t)' },
        { key: 'variance', header: 'MB variance (%)' }, { key: 'status', header: 'Status' }, { key: 'loadedAt', header: 'Loaded' },
      ]} data={data?.live ?? []} title="Latest 25 custody-transfer events" />
      <DataTable columns={[
        { key: 'id', header: 'Mill' }, { key: 'eventTs', header: 'Event (UTC)' }, { key: 'tonnes', header: 'CPO (t)' },
        { key: 'variance', header: 'MB variance (%)' }, { key: 'hint', header: 'Action hint' },
      ]} data={data?.alerts ?? []} title="Custody alert log" />
    </div>
  );
  const planning = (
    <div className="space-y-6">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <KPICard title="Mass-Balance Reconciliation Rate" value={kpiVal('Mass-Balance Reconciliation Rate')} />
        <KPICard title="Supplier Link Coverage" value={kpiVal('Supplier Link Coverage')} />
        <KPICard title="Supplier Verifications Pending" value={kpiVal('Supplier Verifications Pending')} />
      </div>
      <Chart data={data?.reconciliationRisk ?? []} type="scatter" xKey="compliance" xName="Reconciliation rate"
        yKeys={[{ key: 'confirmed', name: 'Confirmed custody breaks' }]} yDomain={[0, 'auto']}
        title="Mass-balance reconciliation rate (%) vs confirmed custody breaks by mill" />
      <p className="text-sm text-slate-600">Synthetic associations are not evidence that reconciliations prevented custody breaks.</p>
      <ActionMemo persona={{ name: 'Sari Wulandari', role: 'Head of Supply Chain Traceability (fictional persona)' }} context={{}}
        onGenerate={async () => {
          const r = await fetch('/api/ask', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ mode: 'memo' }) });
          if (!r.ok) throw new Error('memo failed');
          const j = await r.json();
          return { subject: 'Draft chain-of-custody follow-up actions (synthetic data, human review required)', body: j.answer, urgency: 'review', actions: [] };
        }} />
      <p role="status" className="text-sm text-slate-600">{isAws ? 'Draft generated by Amazon Bedrock (Claude) through a Snowflake external-access function' : 'Draft generated by Snowflake Cortex AI_COMPLETE (Claude Sonnet 4.5)'}, from the KPI, mill, custody-signal and risk tables only. No notification is sent.</p>
    </div>
  );
  const ai = (
    <div className="space-y-4">
      <p role="status">Answers come from the Cortex Agent APP.TRACEABILITY_AGENT. It uses Cortex Analyst over the semantic view APP.TRACEABILITY_ANALYTICS for metrics, and Cortex Search over synthetic chain-of-custody follow-up SOPs for procedures. The generated SQL is shown with each answer.</p>
      <div className="h-[500px]">
        <AskAI title="Ask the traceability agent" mode="advisor" sampleQuestions={['Which 3 mills have the most confirmed custody breaks?', 'Which mills are high risk this week and what SOP applies?', 'What is traceability to plantation by sourcing model?']}
          onSubmit={async (question) => {
            const r = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ question }) });
            if (!r.ok) throw new Error('agent failed');
            const j = await r.json();
            const cites = j.sops?.length ? `\n\nSOPs: ${j.sops.join(', ')}` : '';
            return { answer: `${j.answer}${cites}`, sql: j.sql ?? undefined };
          }} />
      </div>
    </div>
  );
  const architecture = (
    <div className="space-y-4">
      {diagrams.map((d, i) => (
        <div key={d.key} className="space-y-2">
          <h2 className="font-semibold">Architecture: {d.title}{i === 0 ? ' (this deployment)' : ''}</h2>
          <iframe src={d.src} title={`${d.title} architecture diagram`} className="h-[620px] w-full rounded border border-slate-200" />
          <p className="text-sm text-slate-600">Hover a component for details. <a className="underline" href={d.src} target="_blank" rel="noreferrer">Open full screen</a></p>
        </div>
      ))}
      <h2 className="font-semibold">Implementation status</h2>
      <p>Core source: synthetic palm oil mills (8 Indonesian cities x 5 sourcing models), daily mill dispatch observations and an FFB supplier registry. Curated dynamic tables compute numerator/denominator metrics and are suspended after on-demand initialization.</p>
      <p>Application: Next.js server queries the explicit curated contract. Request time and source observation watermark are separate.</p>
      <p>ML: SNOWFLAKE.ML.CLASSIFICATION custody-break risk model evaluated on a time-based holdout, plus a 14-day CPO dispatch FORECAST with prediction intervals.</p>
      <p>ML: ANOMALY_DETECTION flags mass-balance variance outliers per mill over the last 15 days.</p>
      <p>AI: Cortex Agent (Cortex Analyst over a semantic view, plus Cortex Search over SOPs) answers questions. The action memo uses {isAws ? 'Amazon Bedrock Claude through an external-access UDF' : 'Cortex AI_COMPLETE (Claude Sonnet 4.5)'}.</p>
      {isAws ? (
        <>
          <p>AWS ingestion: custody-transfer events sent to Amazon Data Firehose, delivered to S3, then Snowpipe auto-ingest (SQS) into RAW.LIVE_TRANSFERS, with a Snowflake alert and email on FLAG events.</p>
          <p>QuickSight: Snowflake DIRECT_QUERY dashboard (daily custody transfers, confirmed custody breaks by mill, custody-break risk), with a Q topic.</p>
        </>
      ) : (
        <>
          <p>Ingestion: APP.SIMULATE_TRANSFERS inserts simulated custody-transfer events into RAW.LIVE_TRANSFERS, with a Snowflake alert and email on FLAG events. No AWS account is used.</p>
          <p>BI: this SPCS app is the dashboard; natural-language questions go to the Cortex Agent.</p>
        </>
      )}
      <p>Orchestration: the task graph APP.TASK_REFRESH_CURATED, then TASK_RESCORE_RISK, runs on demand. Alerts and tasks stay suspended between demos.</p>
    </div>
  );
  const tabs = [
    { id: 'executive-cockpit', label: 'Executive Cockpit', icon: '', content: executive },
    { id: 'predictive', label: 'Predictive', icon: '', content: predictive },
    { id: 'planning', label: 'Supplier Registry', icon: '', content: planning },
    { id: 'live', label: 'Live Transfers', icon: '', content: liveTab },
    { id: 'ask-ai', label: 'Ask AI', icon: '', content: ai },
    { id: 'architecture', label: 'Architecture & Data', icon: '', content: architecture },
  ].map((tab) => ({ ...tab, content: tab.id === 'architecture' ? tab.content : (
    <div className="space-y-4">
      <p className="text-sm text-slate-600">Synthetic demo data for a fictional palm oil supply chain. On-demand snapshots are not live operations, and custody checks are not audit or certification verdicts.</p>
      {loading ? <p role="status">Loading Snowflake data...</p> : error ? (
        <div role="alert" className="rounded border border-red-200 p-4">
          <p>{error}</p>
          <button className="mt-3 rounded border px-3 py-2" onClick={() => setAttempt((value) => value + 1)}>Retry data connection</button>
        </div>
      ) : !data?.entities.length ? <p role="status">No mill observations are available in this snapshot.</p> : (
        <>
          <p className="text-sm">Observation watermark: {data.sourceWatermark ?? 'Unavailable'}. Request time: {data.requestedAt}.</p>
          {(data.stale || data.pipelineBehind) && <p role="status" className="text-amber-700">Stale or lagging snapshot. Refresh the on-demand pipeline before presenting current results.</p>}
          {tab.content}
        </>
      )}
    </div>
  ) }));
  return <AppLayout title="Indonesia Palm Oil Mill-to-Refinery Traceability" tabs={tabs} />;
}
