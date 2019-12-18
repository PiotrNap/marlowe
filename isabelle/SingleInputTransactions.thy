theory SingleInputTransactions

imports Main Semantics

begin

fun inputsToTransactions :: "SlotInterval \<Rightarrow> Input list \<Rightarrow> Transaction list" where
"inputsToTransactions si Nil = Cons \<lparr> interval = si
                                    , inputs = Nil \<rparr> Nil" |
"inputsToTransactions si (Cons inp1 Nil) = Cons \<lparr> interval = si
                                                 , inputs = Cons inp1 Nil \<rparr> Nil" |
"inputsToTransactions si (Cons inp1 rest) = Cons \<lparr> interval = si
                                                 , inputs = Cons inp1 Nil \<rparr>
                                                 (inputsToTransactions si rest)"

fun traceListToSingleInput :: "Transaction list \<Rightarrow> Transaction list" where
"traceListToSingleInput Nil = Nil" |
"traceListToSingleInput (Cons \<lparr> interval = si
                              , inputs = inps \<rparr> rest) = inputsToTransactions si inps @ (traceListToSingleInput rest)"

lemma reductionLoopIdempotent :
  "reductionLoop env state contract wa pa = ContractQuiescent nwa npa nsta ncont \<Longrightarrow>
   reductionLoop env nsta ncont [] [] = ContractQuiescent [] [] nsta ncont"  
  apply (induction env state contract wa pa rule:reductionLoop.induct)
  subgoal for env state contract warnings payments
    apply (cases "reduceContractStep env state contract")
    apply (cases "reduceContractStep env nsta ncont")
    apply (simp add:Let_def)
    apply simp
    apply simp
    apply metis
    apply simp
    by simp
  done

lemma reduceContractUntilQuiescentIdempotent :           
  "reduceContractUntilQuiescent env state contract = ContractQuiescent wa pa nsta ncont \<Longrightarrow>
   reduceContractUntilQuiescent env nsta ncont = ContractQuiescent [] [] nsta ncont"
  apply (simp only:reduceContractUntilQuiescent.simps)
  using reductionLoopIdempotent by blast  

lemma applyAllLoopEmptyIdempotent :
  "applyAllLoop env sta cont [] a b = ApplyAllSuccess wa pa nsta ncont \<Longrightarrow>
   applyAllLoop env nsta ncont [] c d = ApplyAllSuccess c d nsta ncont"
  apply (simp only:applyAllLoop.simps[of env sta cont])
  apply (cases "reduceContractUntilQuiescent env sta cont")
  using reduceContractUntilQuiescentIdempotent apply auto[1]
  by simp

lemma applyAllLoopJustAppendsWarningsAndEffects :
  "applyAllLoop env st c list (wa @ wt) (ef @ et) = ApplyAllSuccess (wa @ nwa) (ef @ nef) fsta fcont \<Longrightarrow>
   applyAllLoop env st c list (wa2 @ wt) (ef2 @ et) = ApplyAllSuccess (wa2 @ nwa) (ef2 @ nef) fsta fcont"
  apply (induction list arbitrary: env st c wa wt ef et wa2 ef2 nwa nef)
  subgoal for env st c wa wt ef et wa2 ef2 nwa nef
    apply (simp only:applyAllLoop.simps[of env st c])
    apply (cases "reduceContractUntilQuiescent env st c")
    by simp_all
  subgoal for head tail env st c wa wt ef et wa2 ef2 nwa nef
    apply (simp only:applyAllLoop.simps[of env st c "(head # tail)"])
    apply (cases "reduceContractUntilQuiescent env st c")
    subgoal for tempWa tempEf tempState tempContract
      apply (simp only:ReduceResult.case)
      apply (subst list.case(2)[of _ _ head tail])
      apply (subst (asm) list.case(2)[of _ _ head tail])
      apply (cases "applyInput env tempState head tempContract")
      apply (metis ApplyResult.simps(4) append.assoc)
      by simp
    by simp
  done

lemma applyLoopIdempotent_base_case :
  "applyAllLoop env sta cont [] twa tef = ApplyAllSuccess wa pa nsta ncont \<Longrightarrow>
   applyAllLoop env nsta ncont t [] [] = ApplyAllSuccess nwa npa fsta fcont \<Longrightarrow>
   applyAllLoop env sta cont t twa tef = ApplyAllSuccess (wa @ nwa) (pa @ npa) fsta fcont"
  apply (simp only:applyAllLoop.simps[of env sta cont])
  apply (cases "reduceContractUntilQuiescent env sta cont")
  apply (simp only:ReduceResult.case list.case)
  apply (simp only:applyAllLoop.simps[of env nsta ncont])
  apply (cases "reduceContractUntilQuiescent env nsta ncont")
  apply (simp only:ReduceResult.case list.case)
  apply (cases t)
  apply (simp only:list.case)
  using reduceContractUntilQuiescentIdempotent apply auto[1]
  apply (simp only:list.case)
  subgoal for x11 x12 x13 x14 x11a x12a x13a x14a a list
    apply (cases "applyInput env x13a a x14a")
    apply (cases "applyInput env x13 a x14")
    apply (simp only:ApplyResult.case)
    apply (smt ApplyAllResult.inject ApplyResult.inject ReduceResult.inject append.right_neutral append_assoc applyAllLoopJustAppendsWarningsAndEffects convertReduceWarnings.simps(1) reduceContractUntilQuiescentIdempotent self_append_conv2)
    using reduceContractUntilQuiescentIdempotent apply auto[1]
    by simp
   apply simp
  by simp

lemma applyLoopIdempotent :
  "applyAllLoop env sta cont [h] [] [] = ApplyAllSuccess wa pa nsta ncont \<Longrightarrow>
   applyAllLoop env nsta ncont t [] [] = ApplyAllSuccess nwa npa fsta fcont \<Longrightarrow>
   applyAllLoop env sta cont (h # t) [] [] = ApplyAllSuccess (wa @ nwa) (pa @ npa) fsta fcont"
  apply (simp only:applyAllLoop.simps[of env sta cont])
  apply (cases "reduceContractUntilQuiescent env sta cont")
  apply (simp only:ReduceResult.case Let_def list.case)
  subgoal for x11 x12 x13 x14
    apply (cases "applyInput env x13 h x14")
    subgoal for x11a x12a x13a
      using applyLoopIdempotent_base_case by auto
    by simp
  by simp

lemma applyAllIterative :
  "applyAllInputs env sta cont [h] = ApplyAllSuccess wa pa nsta ncont \<Longrightarrow>
   applyAllInputs env nsta ncont t = ApplyAllSuccess nwa npa fsta fcont \<Longrightarrow>
   applyAllInputs env sta cont (h#t) = ApplyAllSuccess (wa @ nwa) (pa @ npa) fsta fcont"
  apply (simp only:applyAllInputs.simps)
  using applyLoopIdempotent by blast

lemma fixIntervalOnlySummary :
  "minSlot state = low \<Longrightarrow> low \<le> high \<Longrightarrow>
   IntervalTrimmed \<lparr> slotInterval = (low, high) \<rparr> state = fixInterval (low, high) state"
  by simp

lemma fixIntervalOnlySummary2 :
  "fixInterval (low, high) state = IntervalTrimmed \<lparr> slotInterval = (nlow, nhigh) \<rparr> nstate \<Longrightarrow>
   nlow = minSlot nstate \<and> low \<le> high"
  apply (cases "high < low")
  apply simp
  apply (cases "high < minSlot state")
  by (auto simp add:Let_def)

lemma fixIntervalChecksInterval :
  "fixInterval inte sta1 = IntervalTrimmed \<lparr>slotInterval = (low, high)\<rparr> sta2 \<Longrightarrow>
   low \<le> high"
  apply (cases inte)
  apply (simp add:Let_def)
  subgoal for low1 high1
    apply (cases "high1 < low1")
    apply simp_all
    apply (cases "high1 < minSlot sta1")
    apply simp_all
    by linarith
  done

lemma fixIntervalIdempotentOnInterval :
  "minSlot sta4 = minSlot sta2 \<Longrightarrow>
   fixInterval (low1, high1) sta1 = IntervalTrimmed \<lparr>slotInterval = (low, high)\<rparr> sta2 \<Longrightarrow>
   fixInterval (low1, high1) sta4 = fixInterval (low, high) sta4"
  apply (cases "high1 < low1")
  apply simp
  apply (cases "high1 < minSlot sta1")
  by (auto simp add:Let_def)

lemma reductionContractStep_preserves_minSlot :
  "reduceContractStep env state contract = Reduced wa ef sta2 cont2 \<Longrightarrow>
   minSlot state = minSlot sta2"
  apply (cases contract)
  apply (auto split:option.splits simp add:Let_def)
  subgoal for x21 x22 x23 x24 x25
  apply (cases "evalValue env state x24 \<le> 0")
    apply simp
    apply (auto split:prod.splits simp add:Let_def)
    done
  apply (auto split:prod.splits simp add:Let_def)
  by (metis ReduceStepResult.distinct(1) ReduceStepResult.distinct(3) ReduceStepResult.inject)

lemma reductionLoop_preserves_minSlot :
  "reductionLoop env sta con wa pa = ContractQuiescent reduceWarns pays sta2 con2 \<Longrightarrow> minSlot sta = minSlot sta2"
  apply (induction env sta con wa pa arbitrary:reduceWarns pays sta2 con2 rule:reductionLoop.induct)
  subgoal for env state contract warnings payments reduceWarns pays sta2 con2
    apply (simp only:reductionLoop.simps[of env state contract warnings payments])
    apply (auto split:ReduceStepResult.splits simp del:reductionLoop.simps)
    using reductionContractStep_preserves_minSlot by auto
  done

lemma reduceContractUntilQuiescent_preserves_minSlot :
  "reduceContractUntilQuiescent env sta con = ContractQuiescent reduceWarns pays sta2 con2 \<Longrightarrow> minSlot sta = minSlot sta2"
  apply (simp only:reduceContractUntilQuiescent.simps)
  by (simp add: reductionLoop_preserves_minSlot)

lemma applyCases_preserves_minSlot :
  "applyCases env curState head x41 = Applied applyWarn newState newCont \<Longrightarrow>
   minSlot curState = minSlot newState"
  apply (induction env curState head x41 arbitrary:applyWarn newCont newState rule:applyCases.induct)
  subgoal for env state accId1 party1 tok1 amount accId2 party2 tok2 val cont rest applyWarn newCont newState
    apply (cases "accId1 = accId2 \<and> party1 = party2 \<and> tok1 = tok2 \<and> amount = evalValue env state val")
    by auto
  subgoal for env state choId1 choice choId2 bounds cont rest applyWarn newCont newState
    apply (cases "choId1 = choId2 \<and> inBounds choice bounds")
    by auto
  subgoal for env state obs cont rest applyWarn newCont newState
    apply (cases "evalObservation env state obs")
    by auto
  by auto

lemma applyInput_preserves_minSlot :
  "applyInput env curState head cont = Applied applyWarn newState newCont \<Longrightarrow> minSlot curState = minSlot newState"
  apply (cases cont)
  by (auto simp add:applyCases_preserves_minSlot)

lemma applyAllLoop_preserves_minSlot :
  "applyAllLoop env sta con inp wa pa = ApplyAllSuccess wa2 pa2 sta2 con2 \<Longrightarrow> minSlot sta = minSlot sta2"
  apply (induction inp arbitrary:env sta con wa pa wa2 pa2 sta2 con2)
  subgoal for env sta con wa pa wa2 pa2 sta2 con2
    apply (simp only:applyAllLoop.simps[of env sta con "[]" wa pa])
    apply (cases "reduceContractUntilQuiescent env sta con")
    subgoal for reduceWarns pays curState cont
      apply (simp del:reduceContractUntilQuiescent.simps)
      using reduceContractUntilQuiescent_preserves_minSlot by blast
      apply (simp del:reduceContractUntilQuiescent.simps)
    done
  subgoal for head tail env sta con wa pa wa2 pa2 sta2 con2
      apply (simp only:applyAllLoop.simps[of env sta con "(head # tail)" wa pa])
      apply (cases "reduceContractUntilQuiescent env sta con")
      subgoal for reduceWarns pays curState cont
        apply (cases "applyInput env curState head cont")
        subgoal for applyWarn newState newCont
          by (simp add: applyInput_preserves_minSlot reduceContractUntilQuiescent_preserves_minSlot)
        by simp
      by simp
    done

lemma applyAllInputs_preserves_minSlot :
  "applyAllInputs env sta con inp = ApplyAllSuccess wa2 pa2 sta2 con2 \<Longrightarrow>
   minSlot sta = minSlot sta2"
  apply (simp only:applyAllInputs.simps)
  using applyAllLoop_preserves_minSlot by blast

lemma applyAllInputs_preserves_minSlot_rev :
   "applyAllInputs env sta con inp = ApplyAllSuccess wa2 pa2 sta2 con2 \<Longrightarrow>
    minSlot sta2 = minSlot sta"
  by (simp add: applyAllInputs_preserves_minSlot)

lemma fixIntervalIdempotentThroughApplyAllInputs :
  "fixInterval inte sta1 = IntervalTrimmed env2 sta2 \<Longrightarrow>
   applyAllInputs env2 sta2 con3 inp1 = ApplyAllSuccess wa4 pa4 sta4 con4 \<Longrightarrow>
   fixInterval inte sta4 = IntervalTrimmed env2 sta4"
  apply (cases env2)
  subgoal for slotInterval
    apply (cases slotInterval)
    subgoal for low high
      apply (simp del:fixInterval.simps applyAllInputs.simps)
      apply (subst fixIntervalOnlySummary)
      apply (metis applyAllInputs_preserves_minSlot eq_fst_iff fixIntervalOnlySummary2)
      using fixIntervalChecksInterval apply blast
      apply (cases inte)
      subgoal for low1 high1
        using applyAllInputs_preserves_minSlot_rev fixIntervalIdempotentOnInterval by blast
      done
    done
  done

lemma smallerSize_implies_different :
  "size cont1 < size cont \<Longrightarrow> cont1 \<noteq> cont"
  by blast

lemma reductionStep_only_makes_smaller :
  "contract \<noteq> ncontract \<Longrightarrow>
   reduceContractStep env state contract = Reduced warning effect newState ncontract \<Longrightarrow> size ncontract < size contract"
  apply (cases contract)
  apply simp
  apply (cases "refundOne (accounts state)")
  apply simp
  apply (simp add: case_prod_beta)
  subgoal for accountId payee token val contract
    apply (simp add:Let_def)
    apply (cases "evalValue env state val \<le> 0")
    apply (simp only:if_True Let_def)
    apply blast
    apply (simp only:if_False Let_def)
    apply (cases "giveMoney payee token (min (moneyInAccount accountId token (accounts state)) (evalValue env state val))
           (updateMoneyInAccount accountId token
             (moneyInAccount accountId token (accounts state) -
              min (moneyInAccount accountId token (accounts state)) (evalValue env state val))
             (accounts state))")
    apply simp
    done
    apply auto[1]
  subgoal for cases timeout contract
    apply simp
    apply (cases "slotInterval env")
    subgoal for low high
      apply simp
      apply (cases "high < timeout")
      apply simp_all
      apply (cases "timeout \<le> low")
      by simp_all
    done
  by (simp add:Let_def)

lemma reductionLoop_only_makes_smaller :
  "cont1 \<noteq> cont \<Longrightarrow>
   reductionLoop env state cont wa pa = ContractQuiescent nwa npa nsta cont1 \<Longrightarrow>
   size cont1 < size cont"
  apply (induction env state cont wa pa arbitrary:cont1 nwa npa nsta rule:reductionLoop.induct)
  subgoal for env state contract warnings payments cont1 nwa npa nsta
    apply (simp only:reductionLoop.simps[of env state contract warnings payments])
    apply (cases "reduceContractStep env state contract")
    subgoal for warning effect newState ncontract
      apply (simp del:reduceContractStep.simps reductionLoop.simps)
      by (metis dual_order.strict_trans reductionStep_only_makes_smaller)
    apply simp
  by simp
  done

lemma reduceContractUntilQuiescent_only_makes_smaller :
  "cont1 \<noteq> cont \<Longrightarrow>
   reduceContractUntilQuiescent env state cont = ContractQuiescent wa pa nsta cont1 \<Longrightarrow>
   size cont1 < size cont"
  apply (simp only:reduceContractUntilQuiescent.simps)
  by (simp add: reductionLoop_only_makes_smaller)

lemma applyCases_only_makes_smaller :
  "applyCases env curState input cases = Applied applyWarn newState cont1 \<Longrightarrow>
   size cont1 < size_list size cases"
  apply (induction env curState input cases rule:applyCases.induct)
  apply auto
  apply (metis ApplyResult.inject less_SucI less_add_Suc1 trans_less_add2)
  apply (metis ApplyResult.inject less_SucI less_add_Suc1 trans_less_add2)
  apply (metis ApplyResult.inject less_SucI less_add_Suc1 trans_less_add2)
  done

lemma applyInput_only_makes_smaller :
  "cont1 \<noteq> cont \<Longrightarrow>
   applyInput env curState input cont = Applied applyWarn newState cont1 \<Longrightarrow>
   size cont1 < size cont"
  apply (cases cont)
  apply simp_all
  subgoal for cases timeout contract
    by (simp add: add.commute applyCases_only_makes_smaller less_SucI trans_less_add2)
  done

lemma applyAllLoop_only_makes_smaller :
  "cont1 \<noteq> cont \<Longrightarrow>
   applyAllLoop env sta cont c wa ef = ApplyAllSuccess cwa1 pa1 sta1 cont1 \<Longrightarrow> cont1 \<noteq> cont \<Longrightarrow> size cont1 < size cont"
  apply (induction env sta cont c wa ef rule:applyAllLoop.induct)
  subgoal for env state contract inputs warnings payments
    apply (simp only:applyAllLoop.simps[of env state contract inputs warnings payments])
    apply (cases "reduceContractUntilQuiescent env state contract")
    apply (simp only:ReduceResult.case)
    subgoal for wa pa nsta cont1
      apply (cases inputs)
      apply (simp only:list.case)
      apply (simp add:reduceContractUntilQuiescent_only_makes_smaller)
      subgoal for head tail
      apply (simp only:list.case)
        apply (cases "applyInput env nsta head cont1")
        subgoal for applyWarn newState cont2
          apply (simp only:ApplyResult.case)
          by (smt applyInput_only_makes_smaller le_trans less_imp_le_nat not_le reduceContractUntilQuiescent_only_makes_smaller)
        by simp
      done
    by simp
  done

lemma applyAllInputs_only_makes_smaller :
  "applyAllInputs env sta cont c = ApplyAllSuccess cwa1 pa1 sta1 cont1 \<Longrightarrow>
   cont1 \<noteq> cont \<Longrightarrow> size cont1 < size cont"
  apply (simp only:applyAllInputs.simps)
  using applyAllLoop_only_makes_smaller by blast

lemma applyAllLoop_longer_doesnt_grow :
  "applyAllLoop env sta cont h wa pa = ApplyAllSuccess cwa1 pa1 sta1 cont1 \<Longrightarrow>
   applyAllLoop env sta cont (h @ t) wa pa = ApplyAllSuccess cwa2 pa2 sta2 cont2 \<Longrightarrow> size cont2 \<le> size cont1"
  apply (induction h arbitrary: env sta cont t wa pa cwa1 pa1 sta1 cont1 cwa2 pa2 sta2 cont2)
  subgoal for env sta cont t wa pa cwa1 pa1 sta1 cont1 cwa2 pa2 sta2 cont2
  apply (subst (asm) applyAllLoop.simps)
  apply (subst (asm) applyAllLoop.simps[of env sta cont "[] @ t"])
  apply (cases "reduceContractUntilQuiescent env sta cont")   
  apply (simp only:ReduceResult.case)
  apply (simp only:list.case append_Nil)
  subgoal for wa pa nsta ncont
    apply (cases t)
    apply (simp only:list.case)
    apply blast
    apply (simp only:list.case)
    subgoal for head tail
      apply (cases "applyInput env nsta head ncont")  
      apply (simp only:ApplyResult.case)
      apply (metis ApplyAllResult.inject applyAllLoop_only_makes_smaller applyInput_only_makes_smaller less_le_trans not_le_imp_less order.asym)
      by simp
    done
  by simp
  subgoal for hh ht env sta cont t wa pa cwa1 pa1 sta1 cont1 cwa2 pa2 sta2 cont2
  apply (subst (asm) applyAllLoop.simps[of env sta cont "(hh # ht)"])
  apply (subst (asm) applyAllLoop.simps[of env sta cont "(hh # ht) @ t"])
  apply (cases "reduceContractUntilQuiescent env sta cont")
  apply (simp only:ReduceResult.case List.append.append_Cons)
  apply (simp only:list.case)
  subgoal for wa pa nsta ncont
    apply (cases "applyInput env nsta hh ncont")
    apply (simp only:ApplyResult.case)
    by simp
  by simp
  done

lemma applyAllInputs_longer_doesnt_grow :
  "applyAllInputs env sta cont h = ApplyAllSuccess cwa1 pa1 sta1 cont1 \<Longrightarrow>
   applyAllInputs env sta cont (h @ t) = ApplyAllSuccess cwa2 pa2 sta2 cont2 \<Longrightarrow>
   size cont2 \<le> size cont1"
  apply (simp only:applyAllInputs.simps)
  by (simp add: applyAllLoop_longer_doesnt_grow)

lemma applyAllInputs_once_modified_always_modified :
  "applyAllInputs env sta cont [h] = ApplyAllSuccess cwa1 pa1 sta1 cont1 \<Longrightarrow>
   cont1 \<noteq> cont \<Longrightarrow>
   applyAllInputs env sta cont (h # t) = ApplyAllSuccess cwa2 pa2 sta2 cont2 \<Longrightarrow>
   cont2 \<noteq> cont"
  apply (rule smallerSize_implies_different)
  by (metis append_Cons append_Nil applyAllInputs.simps applyAllLoop_longer_doesnt_grow applyAllLoop_only_makes_smaller not_le)

lemma computeTransactionIterative_aux :
  "fixInterval inte osta = IntervalTrimmed env sta \<Longrightarrow>
   applyAllInputs env sta cont [h] = ApplyAllSuccess wa pa tsta ncont \<Longrightarrow>
   fixInterval inte tsta = IntervalTrimmed nenv nsta \<Longrightarrow>
   applyAllInputs nenv nsta ncont t = ApplyAllSuccess nwa npa fsta fcont \<Longrightarrow>
   applyAllInputs env sta cont (h # t) = ApplyAllSuccess (wa @ nwa) (pa @ npa) fsta fcont"
  using applyAllIterative fixIntervalIdempotentThroughApplyAllInputs by auto

lemma computeTransactionIterative_aux2 :
  "fixInterval inte sta = IntervalTrimmed fIenv1 fIsta1 \<Longrightarrow>
   applyAllInputs fIenv1 fIsta1 con [h] = ApplyAllSuccess cwa1 pa1 sta1 cont1 \<Longrightarrow>
    \<not> (cont1 = con \<and> (con \<noteq> Close \<or> accounts sta = [])) \<Longrightarrow>
   applyAllInputs fIenv1 fIsta1 con (h # t) = ApplyAllSuccess cwa3 pa3 sta3 cont3 \<Longrightarrow>
    \<not> (cont3 = con \<and> (con \<noteq> Close \<or> accounts sta = []))"
  using applyAllInputs_once_modified_always_modified by blast

lemma computeTransactionIterative :
  "computeTransaction \<lparr> interval = inte
                      , inputs = [h] \<rparr> sta cont = TransactionOutput \<lparr> txOutWarnings = wa
                                                                    , txOutPayments = pa
                                                                    , txOutState = nsta
                                                                    , txOutContract = ncont \<rparr> \<Longrightarrow>
   computeTransaction \<lparr> interval = inte
                      , inputs = t \<rparr> nsta ncont = TransactionOutput \<lparr> txOutWarnings = nwa
                                                                    , txOutPayments = npa
                                                                    , txOutState = fsta
                                                                    , txOutContract = fcont \<rparr> \<Longrightarrow>
   computeTransaction \<lparr> interval = inte
                      , inputs = h#t \<rparr> sta cont = TransactionOutput \<lparr> txOutWarnings = wa @ nwa
                                                                    , txOutPayments = pa @ npa
                                                                    , txOutState = fsta
                                                                    , txOutContract = fcont \<rparr>"
  apply (simp only:computeTransaction.simps)
  apply (cases "fixInterval (interval \<lparr>interval = inte, inputs = [h]\<rparr>) sta")
  subgoal for fIenv1 fIsta1
    apply (simp only:IntervalResult.case Let_def)
    apply (cases "applyAllInputs fIenv1 fIsta1 cont (inputs \<lparr>interval = inte, inputs = [h]\<rparr>)")
    apply (simp only:ApplyAllResult.case)
    subgoal for cwa1 pa1 sta1 con1
      apply (cases "cont = con1 \<and> (cont \<noteq> Close \<or> accounts sta = [])")
      apply simp
      apply (simp only:if_False)
      apply (cases "fixInterval (interval \<lparr>interval = inte, inputs = t\<rparr>) nsta")
      apply (simp only:IntervalResult.case Let_def)
      subgoal for fIenv2 fIsta2
        apply (cases "applyAllInputs fIenv2 fIsta2 ncont (inputs \<lparr>interval = inte, inputs = t\<rparr>)")
        apply (simp only:ApplyAllResult.case)
        subgoal for cwa2 pa2 sta2 con2
          apply (cases "ncont = con2 \<and> (ncont \<noteq> Close \<or> accounts nsta = [])")
          apply simp
          apply (simp only:if_False)
          apply (cases "fixInterval (interval \<lparr>interval = inte, inputs = h # t\<rparr>) sta")
          apply (simp only:IntervalResult.case Let_def)
          subgoal for fIenv3 fIsta3
            apply (cases "applyAllInputs fIenv3 fIsta3 cont (inputs \<lparr>interval = inte, inputs = h # t\<rparr>)")
            apply (simp only:ApplyAllResult.case)
            subgoal for cwa3 pa3 sta3 con3
              apply (cases "(cont = con3) \<and> (cont \<noteq> Close \<or> accounts sta = [])")
              apply (metis IntervalResult.inject(1) Transaction.select_convs(1) Transaction.select_convs(2) computeTransactionIterative_aux2)
              apply (simp only:if_False)
              by (metis ApplyAllResult.inject IntervalResult.inject(1) Transaction.select_convs(1) Transaction.select_convs(2) TransactionOutput.inject(1) TransactionOutputRecord.ext_inject applyAllInputs.simps applyLoopIdempotent fixIntervalIdempotentThroughApplyAllInputs)
            apply (metis (no_types, lifting) ApplyAllResult.distinct(1) IntervalResult.inject(1) Transaction.select_convs(1) Transaction.select_convs(2) TransactionOutput.inject(1) TransactionOutputRecord.ext_inject computeTransactionIterative_aux)
            by (metis (no_types, lifting) ApplyAllResult.distinct(3) IntervalResult.inject(1) Transaction.select_convs(1) Transaction.select_convs(2) TransactionOutput.inject(1) TransactionOutputRecord.ext_inject computeTransactionIterative_aux)
          by simp
        by simp_all
      by simp
    by simp_all
  by simp

lemma expandSingleton : "[a] = Cons a Nil"
  by simp

lemma playTraceAuxIterative_base_case :
  "playTraceAux \<lparr> txOutWarnings = iwa
                , txOutPayments = ipa
                , txOutState = ista
                , txOutContract = icont\<rparr> (Cons \<lparr> interval = inte
                                               , inputs = [h] \<rparr> (Cons \<lparr> interval = inte
                                                                      , inputs = t \<rparr> Nil))
          = TransactionOutput \<lparr> txOutWarnings = wa
                              , txOutPayments = pa
                              , txOutState = nsta
                              , txOutContract = ncont \<rparr> \<Longrightarrow>
   playTraceAux \<lparr> txOutWarnings = iwa
                , txOutPayments = ipa
                , txOutState = ista
                , txOutContract = icont\<rparr> (Cons \<lparr> interval = inte
                                               , inputs = h#t \<rparr> Nil)
          = TransactionOutput \<lparr> txOutWarnings = wa
                              , txOutPayments = pa
                              , txOutState = nsta
                              , txOutContract = ncont \<rparr>"
  apply (cases "computeTransaction \<lparr>interval = inte, inputs = [h]\<rparr> ista icont")
  subgoal for to1
    apply (cases "computeTransaction \<lparr>interval = inte, inputs = h # t\<rparr> ista icont")
    subgoal for to2
      apply (simp del:computeTransaction.simps add:Let_def)
      apply (cases to1)
      subgoal for txOutWarningsa txOutPaymentsa txOutState txOutContract
        apply (cases "computeTransaction \<lparr>interval = inte, inputs = t\<rparr> txOutState txOutContract")
        apply (simp del:computeTransaction.simps add:Let_def)
        subgoal for x1
          by (smt TransactionOutput.inject(1) TransactionOutputRecord.ext_inject TransactionOutputRecord.surjective TransactionOutputRecord.update_convs(1) TransactionOutputRecord.update_convs(2) TransactionOutputRecord_ext_def append.assoc append.right_neutral append_Nil2 append_assoc computeTransactionIterative)
        by simp
      done
    subgoal for to2
      apply (simp del:computeTransaction.simps add:Let_def)
      apply (cases to1)
      subgoal for txOutWarningsa txOutPaymentsa txOutState txOutContract
        apply (cases "computeTransaction \<lparr>interval = inte, inputs = t\<rparr> txOutState txOutContract")
        apply (simp del:computeTransaction.simps add:Let_def)
        subgoal for x1
          by (metis TransactionOutput.simps(4) TransactionOutputRecord.ext_inject TransactionOutputRecord.surjective TransactionOutputRecord.update_convs(1) TransactionOutputRecord.update_convs(2) computeTransactionIterative)
        by simp
      done
    done
  by simp

lemma playTraceAuxIterative :
  "playTraceAux \<lparr> txOutWarnings = iwa
                , txOutPayments = ipa
                , txOutState = ista
                , txOutContract = icont\<rparr> (Cons \<lparr> interval = inte
                                               , inputs = [h] \<rparr> (Cons \<lparr> interval = inte
                                                                      , inputs = t \<rparr> rest))
          = TransactionOutput \<lparr> txOutWarnings = wa
                              , txOutPayments = pa
                              , txOutState = nsta
                              , txOutContract = ncont \<rparr> \<Longrightarrow>
   playTraceAux \<lparr> txOutWarnings = iwa
                , txOutPayments = ipa
                , txOutState = ista
                , txOutContract = icont\<rparr> (Cons \<lparr> interval = inte
                                               , inputs = h#t \<rparr> rest)
          = TransactionOutput \<lparr> txOutWarnings = wa
                              , txOutPayments = pa
                              , txOutState = nsta
                              , txOutContract = ncont \<rparr>"
  apply (induction rest arbitrary: iwa ipa ista icont inte h t wa pa nsta ncont)
  using playTraceAuxIterative_base_case apply blast
  subgoal for restHead restTail iwa ipa ista icont inte h t wa pa nsta ncont
    sorry
  done

lemma playTraceEquivalentWhenError :
  "playTraceAux acc (\<lparr>interval = inte, inputs = h # t\<rparr>#rest) = TransactionError traOut \<Longrightarrow>
   playTraceAux acc (\<lparr>interval = inte, inputs = [h]\<rparr>#\<lparr>interval = inte, inputs = t\<rparr>#rest) = TransactionError traOut"
  sorry

(*
(* Counter example for empty list playTraceEquivalentWhenError_rev *)
value "let acc =
      \<lparr>txOutWarnings = [], txOutPayments = [],
         txOutState = \<lparr>accounts = [], choices = [(ChoiceId 1 1, - 1)], boundValues = [(ValueId 1, 1)], minSlot = - 1\<rparr>,
         txOutContract = When [Case (Choice (ChoiceId 1 1) [(- 1, 1)]) Close] 0 Close\<rparr>;
    h = IChoice (ChoiceId 1 1) 1;
    inte = (- 1, - 1);
    t = [];
    rest = [];
    traOut = TEUselessTransaction in
    (playTraceAux acc (\<lparr>interval = inte, inputs = [h]\<rparr>#\<lparr>interval = inte, inputs = t\<rparr>#rest) = TransactionError traOut \<longrightarrow>
     playTraceAux acc (\<lparr>interval = inte, inputs = h # t\<rparr>#rest) = TransactionError traOut)
  " *)


lemma playTraceEquivalentWhenError_rev :
  "t \<noteq> [] \<Longrightarrow>
   playTraceAux acc (\<lparr>interval = inte, inputs = [h]\<rparr>#\<lparr>interval = inte, inputs = t\<rparr>#rest) = TransactionError traOut \<Longrightarrow>
   playTraceAux acc (\<lparr>interval = inte, inputs = h # t\<rparr>#rest) = TransactionError traOut"
  sorry

lemma playTraceAuxSingleInputIsEquivalent_base_case :
  "t \<noteq> [] \<Longrightarrow>
   playTraceAux acc (Cons \<lparr> interval = inte
                          , inputs = [h] \<rparr> (Cons \<lparr> interval = inte
                                                 , inputs = t \<rparr> Nil))
          =
   playTraceAux acc (Cons \<lparr> interval = inte
                          , inputs = h#t \<rparr> Nil)"
  apply (cases "playTraceAux acc (Cons \<lparr> interval = inte
                          , inputs = [h] \<rparr> (Cons \<lparr> interval = inte
                                                 , inputs = t \<rparr> Nil))")
  subgoal for traOut
    apply (cases "playTraceAux acc (Cons \<lparr> interval = inte
                                         , inputs = h#t \<rparr> Nil)")
    subgoal for traOut2
      apply (cases acc)
      subgoal for accOutWarnings accOutPayments accOutState accOutContract
        apply (cases traOut)
        subgoal for traOutWarnings traOutPayments traOutState traOutContract
          apply (cases traOut2)
          subgoal for traOut2Warnings traOut2Payments traOut2State traOut2Contract
            apply (simp del:playTraceAux.simps)
            by (metis TransactionOutput.inject(1) TransactionOutputRecord.ext_inject playTraceAuxIterative)
          done
        done
      done
    subgoal for traOut2
      by (simp add: playTraceEquivalentWhenError)
    done
  by (simp add: playTraceEquivalentWhenError_rev)


lemma playTraceAuxToSingleInputIsEquivalent_induction_step :
  "(\<And>acc. playTraceAux acc tral = playTraceAux acc (traceListToSingleInput tral)) \<Longrightarrow>
    playTraceAux acc ( \<lparr>interval = interv, inputs = inps\<rparr> # tral)
      = playTraceAux acc (traceListToSingleInput ( \<lparr>interval = interv, inputs = inps\<rparr> # tral))"
  apply (induction inps arbitrary:acc tral)
  apply simp
  subgoal for acc tral
    apply (cases acc)
    subgoal for txOutWarnings txOutPayments txOutState txOutContract
      apply (simp only:playTraceAux.simps)
      done
    done
  subgoal for head tail acc tral
    apply (cases acc)
    subgoal for txOutWarnings txOutPayments txOutState txOutContract
      apply (cases tail)
      apply (simp only:traceListToSingleInput.simps inputsToTransactions.simps playTraceAux.simps)
       apply simp
      subgoal for tailHead tailTail
        apply (simp only:traceListToSingleInput.simps inputsToTransactions.simps)
        sledgehammer
      sorry
    done
  done

lemma playTraceAuxToSingleInputIsEquivalent :
  "playTraceAux acc tral = playTraceAux acc (traceListToSingleInput tral)"
  apply (induction tral arbitrary:acc)
  apply simp
  by (metis Transaction.cases playTraceAuxToSingleInputIsEquivalent_induction_step)

theorem traceToSingleInputIsEquivalent : "playTrace sn co tral = playTrace sn co (traceListToSingleInput tral)"
  apply (simp only:playTrace.simps)
  using playTraceAuxToSingleInputIsEquivalent by blast

end