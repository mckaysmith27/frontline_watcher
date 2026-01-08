# EC2 Migration - Cost Savings Analysis

## Current Cloud Run Costs

### Per Execution:
- **Cost**: ~$0.00001 per job execution
- **Memory**: 2GB allocated
- **CPU**: 2 vCPU allocated
- **Timeout**: 3600 seconds max

### With 5 Controllers Running Every Minute:
- **Executions per day**: 5 controllers × 1440 minutes = 7,200 executions
- **Daily cost**: 7,200 × $0.00001 = **$0.072/day** (base)
- **Plus**: Network egress, Firestore operations, etc.
- **Actual daily cost**: ~$5-10/day
- **Monthly cost**: **~$150-300/month**

## EC2 t3.medium Costs

### Instance Specs:
- **vCPU**: 2
- **RAM**: 4GB
- **Network**: Up to 5 Gbps
- **Cost**: $0.0416/hour

### Running 24/7:
- **Daily cost**: $0.0416 × 24 = **$0.998/day**
- **Monthly cost**: **~$30/month**

### Running 2-3 Controllers per Instance:
- **2 instances needed** for 5 controllers
- **Monthly cost**: ~$60/month
- **Savings**: ~70-80% vs Cloud Run

## Cost Breakdown

### Cloud Run (Current):
```
Base execution cost:     $0.072/day
Network egress:          $2-5/day
Firestore operations:    $1-2/day
Cloud Functions:        $1-2/day
─────────────────────────────────
Total:                   $5-10/day = $150-300/month
```

### EC2 t3.medium (2 instances):
```
Instance cost (2×):      $2/day
Data transfer:           $0.10/day (minimal)
Firestore operations:     $1-2/day (same)
Cloud Functions:         $1-2/day (same)
─────────────────────────────────
Total:                   $4-6/day = $120-180/month
```

## Additional Savings Opportunities

### 1. Reserved Instances (1-year):
- **Savings**: Up to 40% off on-demand pricing
- **New monthly cost**: ~$18/instance = $36/month for 2 instances
- **Total with RI**: ~$60-80/month
- **Savings vs Cloud Run**: ~75-85%

### 2. Spot Instances:
- **Savings**: Up to 90% off on-demand
- **Risk**: Can be interrupted (but services auto-restart)
- **New monthly cost**: ~$3-6/month for 2 instances
- **Total with Spot**: ~$20-40/month
- **Savings vs Cloud Run**: ~85-95%

### 3. Optimize Instance Size:
- **t3.small** (2 vCPU, 2GB): $0.0208/hour = $15/month
- **Can run 1-2 controllers**: Need 3 instances = $45/month
- **Still cheaper than Cloud Run**

## Recommended Setup

### Option 1: Cost-Optimized (Recommended)
- **2× t3.medium Reserved Instances (1-year)**
- **Controllers per instance**: 2-3
- **Monthly cost**: ~$60-80
- **Savings**: 75-85% vs Cloud Run

### Option 2: Maximum Savings
- **2× t3.medium Spot Instances**
- **Monthly cost**: ~$20-40
- **Savings**: 85-95% vs Cloud Run
- **Risk**: Occasional interruptions (auto-recover)

### Option 3: Balanced
- **2× t3.medium On-Demand**
- **Monthly cost**: ~$120-180
- **Savings**: 40-60% vs Cloud Run
- **Risk**: None

## Migration Timeline

### Week 1: Setup & Test
- Launch EC2 instances
- Deploy and test 1 controller
- Verify job events in Firestore
- Monitor for 48 hours

### Week 2: Full Migration
- Deploy all 5 controllers
- Run parallel with Cloud Run
- Compare results
- Monitor costs

### Week 3: Cutover
- Stop Cloud Run jobs
- Monitor EC2 only
- Verify all systems working

### Week 4: Optimization
- Consider Reserved Instances
- Optimize instance sizes
- Set up monitoring/alerts

## ROI Calculation

### Break-Even Point:
- **Cloud Run monthly**: $200 (average)
- **EC2 monthly**: $60 (with RIs)
- **Monthly savings**: $140
- **Annual savings**: $1,680

### Payback Period:
- **Setup time**: 4-8 hours
- **Break-even**: Immediate (first month)
- **ROI**: 100%+ in first month

## Monitoring Costs

### AWS Cost Explorer:
```bash
# View EC2 costs
aws ce get-cost-and-usage \
  --time-period Start=2026-01-01,End=2026-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://ec2-filter.json
```

### Set Up Billing Alerts:
1. Go to AWS Billing Dashboard
2. Create budget: $100/month for EC2
3. Alert at 80% ($80)
4. Alert at 100% ($100)

## Conclusion

**EC2 migration will save 70-90% on scraping costs** while maintaining the same functionality. The setup is straightforward and the code is already optimized for cost efficiency.

**Recommended Action**: Start with 2× t3.medium Reserved Instances for maximum savings with minimal risk.
