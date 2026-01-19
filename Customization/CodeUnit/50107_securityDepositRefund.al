codeunit 50107 "Security Deposit Posting Mgt."
{
    procedure PostSecurityDepositAmount(SecurityDeposit: Record "Security Deposit")
    var
        GenJnlLine: Record "Gen. Journal Line";
        COASetup: Record "COA Setup";
        GenJnlTemplate: Code[10];
        GenJnlBatch: Code[10];
        Amount: Decimal;
        PropertyType: Text[30];
        TenantReceivableAccount: Code[20];
        CarryForwardOutAccount: Code[20];
        CarryForwardInAccount: Code[20];
        LineNo: Integer;
        GenJnlPost: Codeunit "Gen. Jnl.-Post";
        DocNo: Code[20];
    begin
        // Set Cash Receipt Journal Template and Batch
        GenJnlTemplate := 'CASH RECE';
        GenJnlBatch := 'DEFAULT';

        Amount := SecurityDeposit."Carry Forward Amount";
        PropertyType := SecurityDeposit."Property Classification";

        if Amount = 0 then
            Error('Security Deposit Amount Received is zero. Cannot post.');

        // Set G/L Accounts based on Property Type
        // case PropertyType of
        //     'Residential':
        //         TenantReceivableAccount := '1501';
        //     'Commercial':
        //         TenantReceivableAccount := '1506';
        //     else
        //         Error('Invalid Property Type. Must be Residential or Commercial.');
        // end;
        COASetup.Get();
        if PropertyType = 'Residential' then begin
            if COASetup."Tenant Receivables-Residential" <> '' then begin
                TenantReceivableAccount := COASetup."Tenant Receivables-Residential";
            end
            else
                Error('COA Setup doest not exist for Tenant Receivables-Residential Account');

        end else begin
            if COASetup."Tenant Receivables-Commercial" <> '' then begin
                TenantReceivableAccount := COASetup."Tenant Receivables-Commercial";
            end
            else
                Error('COA Setup doest not exist for Tenant Receivables-Commercial Account');
        end;




        CarryForwardOutAccount := COASetup."Carried Forward Out SD";
        CarryForwardInAccount := COASetup."Carried Forward in SD";

        // Generate Document No
        DocNo := 'SD-' + Format(SecurityDeposit."Contract ID");

        // Find the next available Line No.
        GenJnlLine.Reset();
        GenJnlLine.SetRange("Journal Template Name", GenJnlTemplate);
        GenJnlLine.SetRange("Journal Batch Name", GenJnlBatch);
        if GenJnlLine.FindLast() then
            LineNo := GenJnlLine."Line No." + 1
        else
            LineNo := 1;

        // 1st Line - Tenant Receivable (-Amount)
        Clear(GenJnlLine);
        GenJnlLine.Init();
        GenJnlLine."Journal Template Name" := GenJnlTemplate;
        GenJnlLine."Journal Batch Name" := GenJnlBatch;
        GenJnlLine."Line No." := LineNo;
        GenJnlLine."Posting Date" := Today;
        GenJnlLine."Document No." := DocNo;
        GenJnlLine.Description := SecurityDeposit.Narration;
        GenJnlLine.Validate("Account Type", GenJnlLine."Account Type"::Customer);
        GenJnlLine.Validate("Account No.", SecurityDeposit."Tenant ID");
        GenJnlLine.Validate(Amount, -Amount);
        GenJnlLine."Contract ID" := SecurityDeposit."Contract ID";

        GenJnlLine.Insert();

        // 2nd Line - Carry Forward Out (+Amount)
        LineNo += 10000;
        Clear(GenJnlLine);
        GenJnlLine.Init();
        GenJnlLine."Journal Template Name" := GenJnlTemplate;
        GenJnlLine."Journal Batch Name" := GenJnlBatch;
        GenJnlLine."Line No." := LineNo;
        GenJnlLine."Posting Date" := Today;
        GenJnlLine."Document No." := DocNo;
        GenJnlLine.Description := SecurityDeposit.Narration;
        GenJnlLine.Validate("Account Type", GenJnlLine."Account Type"::"G/L Account");
        GenJnlLine.Validate("Account No.", CarryForwardOutAccount);
        GenJnlLine.Validate(Amount, Amount);
        GenJnlLine."Contract ID" := SecurityDeposit."Contract ID";
        GenJnlLine.Insert();

        // 3rd Line - Carry Forward In (-Amount)
        LineNo += 10000;
        Clear(GenJnlLine);
        GenJnlLine.Init();
        GenJnlLine."Journal Template Name" := GenJnlTemplate;
        GenJnlLine."Journal Batch Name" := GenJnlBatch;
        GenJnlLine."Line No." := LineNo;
        GenJnlLine."Posting Date" := Today;
        GenJnlLine."Document No." := DocNo;
        GenJnlLine.Description := SecurityDeposit.Narration;
        GenJnlLine.Validate("Account Type", GenJnlLine."Account Type"::"G/L Account");
        GenJnlLine.Validate("Account No.", CarryForwardInAccount);
        GenJnlLine.Validate(Amount, -Amount);
        GenJnlLine."Contract ID" := SecurityDeposit."New_Contract ID";
        GenJnlLine.Insert();

        // 4th Line - Tenant Receivable (+Amount)
        LineNo += 10000;
        Clear(GenJnlLine);
        GenJnlLine.Init();
        GenJnlLine."Journal Template Name" := GenJnlTemplate;
        GenJnlLine."Journal Batch Name" := GenJnlBatch;
        GenJnlLine."Line No." := LineNo;
        GenJnlLine."Posting Date" := Today;
        GenJnlLine."Document No." := DocNo;
        GenJnlLine.Description := SecurityDeposit.Narration;
        GenJnlLine.Validate("Account Type", GenJnlLine."Account Type"::Customer);
        GenJnlLine.Validate("Account No.", SecurityDeposit."Tenant ID");
        GenJnlLine.Validate(Amount, Amount);
        GenJnlLine."Contract ID" := SecurityDeposit."New_Contract ID";
        GenJnlLine.Insert();

        // Now Post the Journal
        GenJnlPost.Run(GenJnlLine);

        Message('Security Deposit posted successfully.');
    end;
}
